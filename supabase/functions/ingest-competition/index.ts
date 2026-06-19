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
        price,
        tournament_id,
        golfer_profile_id,
        golfer_profiles (
          espn_id
        )
      `)
      .eq('tournament_id', tournamentId)

    if (tgError || !tgGolfers) {
      throw new Error(`Failed to fetch tournament golfers: ${tgError?.message}`)
    }

    const tgMap = new Map<string, { id: string, price: number, tournament_id: string, golfer_profile_id: string }>() // espn_id -> tg details
    for (const tg of tgGolfers) {
      const espnId = (tg.golfer_profiles as any)?.espn_id
      if (espnId) {
        tgMap.set(espnId, {
          id: tg.id,
          price: tg.price,
          tournament_id: tg.tournament_id,
          golfer_profile_id: tg.golfer_profile_id,
        })
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

    const tgUpserts: any[] = []
    const teeTimeUpserts: any[] = []
    const holeScoreUpserts: any[] = []

    // Fetch player linescores in parallel batches (e.g., 15 at a time) to prevent worker limits and rate limits
    const batchSize = 15
    for (let i = 0; i < competitors.length; i += batchSize) {
      const batch = competitors.slice(i, i + batchSize)
      await Promise.all(
        batch.map(async (competitor: any) => {
          const espnId = competitor.id
          const tg = tgMap.get(espnId)
          if (!tg) return // golfer not in active tournament field

          // Map competitor status
          const stateName = competitor.status?.type?.name ?? ""
          const tgStatus = stateName === "STATUS_CUT" ? "MC" : 
                           stateName === "STATUS_WITHDRAWN" ? "WD" : "ACTIVE"

          tgUpserts.push({
            id: tg.id,
            tournament_id: tg.tournament_id,
            golfer_profile_id: tg.golfer_profile_id,
            price: tg.price,
            status: tgStatus,
          })

          // Fetch player's detailed linescores (includes hole-by-hole data)
          const linescoresRes = await fetch(
            `https://sports.core.api.espn.com/v2/sports/golf/leagues/pga/events/${espnEventId}/competitions/${espnEventId}/competitors/${espnId}/linescores`
          )
          if (!linescoresRes.ok) {
            console.error(`Failed to fetch linescores for golfer ${espnId}: ${linescoresRes.statusText}`)
            return
          }
          const linescoresData = await linescoresRes.json()

          // Iterate through rounds
          for (const roundItem of linescoresData.items || []) {
            const roundNum = roundItem.period // 1, 2, 3, 4
            const roundTeeTime = roundItem.teeTime // "2026-06-11T16:59Z"

            // Collect tee time
            if (roundTeeTime) {
              const startTee = competitor.status?.startHole ?? 1
              teeTimeUpserts.push({
                tournament_golfer_id: tg.id,
                round: roundNum,
                tee_time_utc: roundTeeTime,
                start_tee: startTee,
                status: tgStatus,
              })
            }

            // Collect hole scores
            for (const holeItem of roundItem.linescores || []) {
              const holeNum = holeItem.period // 1 to 18
              const score = holeItem.value // raw strokes
              const par = holeItem.par
              const scoreTypeName = holeItem.scoreType?.name ?? "PAR"

              if (score !== undefined && score !== null) {
                holeScoreUpserts.push({
                  tournament_golfer_id: tg.id,
                  round: roundNum,
                  hole: holeNum,
                  par,
                  score: Math.round(score),
                  score_type: scoreTypeName,
                })
              }
            }
          }
          processedCount++
        })
      )
    }

    // Helper function to chunk arrays for batch upsert
    const chunkArray = <T>(array: T[], size: number): T[][] => {
      const chunked: T[][] = []
      for (let i = 0; i < array.length; i += size) {
        chunked.push(array.slice(i, i + size))
      }
      return chunked
    }

    // Bulk upsert tournament_golfers status
    const tgChunks = chunkArray(tgUpserts, 1000)
    for (const chunk of tgChunks) {
      const { error: tgUpsertError } = await supabaseClient
        .from('tournament_golfers')
        .upsert(chunk, { onConflict: 'id' })
      if (tgUpsertError) {
        throw new Error(`Failed to upsert tournament golfers: ${tgUpsertError.message}`)
      }
    }

    // Bulk upsert tee_times
    const teeTimeChunks = chunkArray(teeTimeUpserts, 1000)
    for (const chunk of teeTimeChunks) {
      const { error: teeTimeError } = await supabaseClient
        .from('tee_times')
        .upsert(chunk, { onConflict: 'tournament_golfer_id,round' })
      if (teeTimeError) {
        throw new Error(`Failed to upsert tee times: ${teeTimeError.message}`)
      }
    }

    // Bulk upsert hole_scores
    const holeScoreChunks = chunkArray(holeScoreUpserts, 1000)
    for (const chunk of holeScoreChunks) {
      const { error: holeScoreError } = await supabaseClient
        .from('hole_scores')
        .upsert(chunk, { onConflict: 'tournament_golfer_id,round,hole' })
      if (holeScoreError) {
        throw new Error(`Failed to upsert hole scores: ${holeScoreError.message}`)
      }
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
