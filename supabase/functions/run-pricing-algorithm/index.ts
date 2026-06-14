import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"
import { computeGolferPrice } from "./pricing_helper.ts"

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

    // 1. Fetch active tournament
    const { data: activeTournaments, error: tError } = await supabaseClient
      .from('tournaments')
      .select('id')
      .neq('status', 'COMPLETED')
      .order('start_date', { ascending: false })
      .limit(1)

    if (tError || !activeTournaments || activeTournaments.length === 0) {
      throw new Error(`Failed to fetch active tournament: ${tError?.message || 'None found'}`)
    }
    const tournamentId = activeTournaments[0].id

    // 2. Fetch all tournament golfers
    const { data: tgGolfers, error: tgError } = await supabaseClient
      .from('tournament_golfers')
      .select(`
        id,
        golfer_profile_id,
        golfer_profiles (
          id,
          name,
          world_rank,
          scoring_avg,
          wins,
          top_10s,
          cuts_made,
          events_played,
          rounds_played,
          prior_scoring_avg,
          prior_wins,
          prior_top_10s,
          prior_cuts_made,
          prior_events_played,
          prior_rounds_played
        )
      `)
      .eq('tournament_id', tournamentId)

    if (tgError || !tgGolfers || tgGolfers.length === 0) {
      throw new Error(`Failed to fetch tournament golfers: ${tgError?.message || 'None found'}`)
    }

    // 3. To find min/max average scoring of the active field, we first pre-calculate blended scoringAvg
    const N = 8
    const blends = tgGolfers.map((tg) => {
      const golfer = tg.golfer_profiles as any
      if (!golfer) return null

      const currentEvents = golfer.events_played ?? 0
      const priorEvents = golfer.prior_events_played ?? 0
      const hasPriorData = priorEvents > 0

      if (currentEvents === 0 && !hasPriorData) {
        return null // zero-data
      }

      const priorWeight = Math.max(0, 1 - currentEvents / N)
      const currentRounds = golfer.rounds_played ?? 0
      const priorRounds = golfer.prior_rounds_played ?? 0
      const blendedRounds = currentRounds + priorWeight * priorRounds

      let scoringAvg = 72.0
      if (blendedRounds > 0) {
        scoringAvg = ((currentRounds * (golfer.scoring_avg ?? 72.0)) + 
                      (priorWeight * priorRounds * (golfer.prior_scoring_avg ?? 72.0))) / blendedRounds
      } else {
        scoringAvg = golfer.scoring_avg ?? golfer.prior_scoring_avg ?? 72.0
      }

      return scoringAvg
    }).filter((x): x is number => x !== null)

    let minAvg = 72.0
    let maxAvg = 72.0
    if (blends.length > 0) {
      minAvg = Math.min(...blends)
      maxAvg = Math.max(...blends)
    }

    // 4. Calculate prices and update
    const priceUpdates = []
    for (const tg of tgGolfers) {
      const golfer = tg.golfer_profiles as any
      if (!golfer) continue

      const { price } = computeGolferPrice(golfer, minAvg, maxAvg)

      const { error: updateError } = await supabaseClient
        .from('tournament_golfers')
        .update({ price })
        .eq('id', tg.id)

      if (updateError) {
        console.error(`Error updating price for tournament_golfer ${tg.id}: ${updateError.message}`)
      } else {
        priceUpdates.push({ tgId: tg.id, price })
      }
    }

    return new Response(
      JSON.stringify({ 
        message: "Pricing algorithm executed successfully.", 
        golfers_priced: priceUpdates.length,
        price_summary: {
          min_avg_used: minAvg,
          max_avg_used: maxAvg,
        }
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
