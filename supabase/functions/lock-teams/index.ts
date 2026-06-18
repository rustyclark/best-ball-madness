import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Fetch active tournaments where lock time has passed
    const now = new Date().toISOString()
    const { data: tournaments, error: tError } = await supabaseClient
      .from('tournaments')
      .select('id, name, lock_time_utc')
      .neq('status', 'COMPLETED')
      .lte('lock_time_utc', now)

    if (tError || !tournaments || tournaments.length === 0) {
      return new Response(
        JSON.stringify({ message: "No locked tournaments require evaluation." }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    const dqUpdates = []
    for (const tournament of tournaments) {
      // Fetch active teams for this tournament
      const { data: teams, error: teamsError } = await supabaseClient
        .from('teams')
        .select(`
          id,
          status,
          team_golfers (
            id,
            tournament_golfers (
              price
            )
          )
        `)
        .eq('tournament_id', tournament.id)
        .eq('status', 'ACTIVE')

      if (teamsError || !teams) {
        console.error(`Error loading teams for tournament ${tournament.name}: ${teamsError?.message}`)
        continue
      }

      for (const team of teams) {
        const golfers = team.team_golfers || []
        const count = golfers.length
        
        let spend = 0
        for (const g of golfers) {
          const price = (g.tournament_golfers as any)?.price ?? 0
          spend += Number(price)
        }

        let isDq = false
        let dqReason = ""

        if (count > 0) {
          if (count < 4) {
            isDq = true
            dqReason = "incomplete"
          } else if (spend > 100) {
            isDq = true
            dqReason = "over_budget"
          }
        } else {
          // If count === 0 (empty team), check if it's still possible to draft 4 golfers who haven't teed off
          const { data: availableGolfers, error: availError } = await supabaseClient
            .from('tournament_golfers')
            .select(`
              id,
              tee_times (
                tee_time_utc,
                round
              )
            `)
            .eq('tournament_id', tournament.id)

          if (!availError && availableGolfers) {
            const now = new Date()
            const unteedGolfers = availableGolfers.filter((g: any) => {
              const r1Tee = (g.tee_times || []).find((t: any) => t.round === 1)
              if (!r1Tee || !r1Tee.tee_time_utc) return true
              return now < new Date(r1Tee.tee_time_utc)
            })

            if (unteedGolfers.length < 4) {
              isDq = true
              dqReason = "incomplete"
            }
          }
        }

        // DQ condition: roster is incomplete or budget exceeded
        if (isDq) {
          const { error: updateError } = await supabaseClient
            .from('teams')
            .update({ status: 'DQ' })
            .eq('id', team.id)

          if (updateError) {
            console.error(`Failed to DQ team ${team.id}: ${updateError.message}`)
          } else {
            dqUpdates.push({ team_id: team.id, reason: dqReason })
          }
        }
      }

      // If we performed DQ updates, trigger a leaderboard standings refresh
      if (dqUpdates.length > 0) {
        const { error: rpcError } = await supabaseClient.rpc('recompute_leaderboard', { t_id: tournament.id })
        if (rpcError) {
          console.error(`Leaderboard recompute failed post-DQ updates: ${rpcError.message}`)
        }
      }
    }

    return new Response(
      JSON.stringify({
        message: "Roster lock evaluation completed.",
        teams_disqualified: dqUpdates,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
