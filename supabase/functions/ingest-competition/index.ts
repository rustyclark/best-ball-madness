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

    // 1. Fetch active tournament
    const { data: activeTournaments, error: tError } = await supabaseClient
      .from('tournaments')
      .select('id, espn_event_id, status, current_round, lock_time_utc')
      .neq('status', 'COMPLETED')
      .order('start_date', { ascending: false })
      .limit(1)

    if (tError || !activeTournaments || activeTournaments.length === 0) {
      throw new Error(`Failed to fetch active tournament: ${tError?.message || 'None found'}`)
    }
    const tournament = activeTournaments[0]
    const tournamentId = tournament.id
    const espnEventId = tournament.espn_event_id

    // 2. Fetch the leaderboard from ESPN to get the active field and status
    const leaderboardRes = await fetch("https://site.api.espn.com/apis/site/v2/sports/golf/leaderboard?league=pga")
    if (!leaderboardRes.ok) {
      throw new Error(`Failed to fetch ESPN leaderboard: ${leaderboardRes.statusText}`)
    }
    const leaderboardData = await leaderboardRes.json()
    const event = leaderboardData.events?.[0]
    if (!event || event.id !== espnEventId) {
      throw new Error(`Event mismatch. Active DB event: ${espnEventId}, ESPN current event: ${event?.id}`)
    }

    // 3. Fetch current tournament golfers in our database to map espn_id to tournament_golfer_id
    const { data: tgGolfers, error: tgError } = await supabaseClient
      .from('tournament_golfers')
      .select(`
        id,
        golfer_profiles (
          espn_id
        )
      `)
      .eq('tournament_id', tournamentId)

    if (tgError || !tgGolfers) {
      throw new Error(`Failed to fetch tournament golfers: ${tgError?.message}`)
    }

    const tgMap = new Map<string, string>() // espn_id -> tournament_golfer_id
    for (const tg of tgGolfers) {
      const espnId = (tg.golfer_profiles as any)?.espn_id
      if (espnId) {
        tgMap.set(espnId, tg.id)
      }
    }

    // 4. Update tournament state
    const rawState = event.status?.type?.name ?? "STATUS_SCHEDULED"
    let status = "SCHEDULED"
    if (rawState === "STATUS_IN_PROGRESS") {
      status = "IN_PROGRESS"
    } else if (rawState === "STATUS_SUSPENDED") {
      status = "SUSPENDED"
    } else if (rawState === "STATUS_FINAL" || rawState === "STATUS_FINAL_SHORT" || rawState === "STATUS_COMPLETED") {
      status = "COMPLETED"
    }

    const currentRound = event.status?.period ?? 1

    await supabaseClient
      .from('tournaments')
      .update({ status, current_round: currentRound })
      .eq('id', tournamentId)

    // 5. Ingest hole scores and tee times per competitor
    const competitors = event.competitions?.[0]?.competitors || []
    let processedCount = 0

    for (const competitor of competitors) {
      const espnId = competitor.id
      const tgId = tgMap.get(espnId)
      if (!tgId) continue // golfer not in active tournament field

      // Map competitor status
      const stateName = competitor.status?.type?.name ?? ""
      const tgStatus = stateName === "STATUS_CUT" ? "MC" : 
                       stateName === "STATUS_WITHDRAWN" ? "WD" : "ACTIVE"

      // Update tournament golfer status
      await supabaseClient
        .from('tournament_golfers')
        .update({ status: tgStatus })
        .eq('id', tgId)

      // Fetch player's detailed linescores (includes hole-by-hole data)
      const linescoresRes = await fetch(
        `https://sports.core.api.espn.com/v2/sports/golf/leagues/pga/events/${espnEventId}/competitions/${espnEventId}/competitors/${espnId}/linescores`
      )
      if (!linescoresRes.ok) {
        console.error(`Failed to fetch linescores for golfer ${espnId}: ${linescoresRes.statusText}`)
        continue
      }
      const linescoresData = await linescoresRes.json()

      // Iterate through rounds (items represent rounds)
      for (const roundItem of linescoresData.items || []) {
        const roundNum = roundItem.period // 1, 2, 3, 4
        const roundTeeTime = roundItem.teeTime // "2026-06-11T16:59Z"

        // Upsert tee time
        if (roundTeeTime) {
          const startTee = competitor.status?.startHole ?? 1
          await supabaseClient
            .from('tee_times')
            .upsert({
              tournament_golfer_id: tgId,
              round: roundNum,
              tee_time_utc: roundTeeTime,
              start_tee: startTee,
              status: tgStatus,
            }, { onConflict: 'tournament_golfer_id,round' })
        }

        // Upsert hole scores
        for (const holeItem of roundItem.linescores || []) {
          const holeNum = holeItem.period // 1 to 18
          const score = holeItem.value // raw strokes (e.g. 4.0)
          const par = holeItem.par // e.g. 5
          const scoreTypeName = holeItem.scoreType?.name ?? "PAR"

          if (score !== undefined && score !== null) {
            await supabaseClient
              .from('hole_scores')
              .upsert({
                tournament_golfer_id: tgId,
                round: roundNum,
                hole: holeNum,
                par,
                score: Math.round(score),
                score_type: scoreTypeName,
              }, { onConflict: 'tournament_golfer_id,round,hole' })
          }
        }
      }
      processedCount++
    }

    // 6. Lock Time Auto-Computation (Round 1 earliest tee time - 15 minutes)
    if (!tournament.lock_time_utc) {
      const { data: r1TeeTimes, error: r1Error } = await supabaseClient
        .from('tee_times')
        .select('tee_time_utc')
        .eq('round', 1)
        .order('tee_time_utc', { ascending: true })
        .limit(1)

      if (!r1Error && r1TeeTimes && r1TeeTimes.length > 0) {
        const earliestTeeTime = new Date(r1TeeTimes[0].tee_time_utc)
        const lockTime = new Date(earliestTeeTime.getTime() - 15 * 60 * 1000)
        
        await supabaseClient
          .from('tournaments')
          .update({ lock_time_utc: lockTime.toISOString() })
          .eq('id', tournamentId)
      }
    }

    // 7. Invoke Stored Procedure to evaluate cuts and recompute leaderboard_standings
    const { error: rpcError } = await supabaseClient.rpc('recompute_leaderboard', { t_id: tournamentId })
    if (rpcError) {
      throw new Error(`RPC recompute_leaderboard failed: ${rpcError.message}`)
    }

    return new Response(
      JSON.stringify({
        message: "Competition scores ingested and leaderboard updated.",
        golfers_processed: processedCount,
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
