import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"
import { computeGolferPrice, computePriceFromPercentile } from "./pricing_helper.ts"

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

      const rawScoringAvg = golfer.scoring_avg && golfer.scoring_avg > 0 ? golfer.scoring_avg : 72.0
      const rawPriorScoringAvg = golfer.prior_scoring_avg && golfer.prior_scoring_avg > 0 ? golfer.prior_scoring_avg : 72.0

      let scoringAvg = 72.0
      if (blendedRounds > 0) {
        scoringAvg = ((currentRounds * rawScoringAvg) + 
                      (priorWeight * priorRounds * rawPriorScoringAvg)) / blendedRounds
      } else {
        scoringAvg = rawScoringAvg
      }

      return scoringAvg
    }).filter((x): x is number => x !== null)

    let minAvg = 72.0
    let maxAvg = 72.0
    if (blends.length > 0) {
      minAvg = Math.min(...blends)
      maxAvg = Math.max(...blends)
    }

    // 4. Sort and compute relative world rank percentile scores for the active field to handle weaker fields dynamically
    const sortedGolfers = [...tgGolfers].sort((a, b) => {
      const rankA = (a.golfer_profiles as any)?.world_rank ?? 9999
      const rankB = (b.golfer_profiles as any)?.world_rank ?? 9999
      return rankA - rankB
    })

    const fieldSize = sortedGolfers.length
    const rankMap = new Map<string, number>()

    let currentRank = 0
    let prevVal = -1
    for (let i = 0; i < fieldSize; i++) {
      const tg = sortedGolfers[i]
      const val = (tg.golfer_profiles as any)?.world_rank ?? 9999
      if (val !== prevVal) {
        currentRank = i
        prevVal = val
      }
      const relativeScore = fieldSize > 1 ? (fieldSize - 1 - currentRank) / (fieldSize - 1) : 1.0
      rankMap.set(tg.id, relativeScore)
    }

    // 5. Calculate raw combined score for each golfer
    const golferScores = []
    for (const tg of tgGolfers) {
      const golfer = tg.golfer_profiles as any
      if (!golfer) continue

      const relativeWorldRankScore = rankMap.get(tg.id) ?? 0.0
      const { isZeroData, combinedScore } = computeGolferPrice(golfer, minAvg, maxAvg, relativeWorldRankScore)
      golferScores.push({
        tgId: tg.id,
        isZeroData,
        combinedScore,
      })
    }

    // 6. Sort by combinedScore to compute relative combined percentile rank
    const sortedScores = [...golferScores].sort((a, b) => a.combinedScore - b.combinedScore)
    const scoresSize = sortedScores.length
    const combinedPercentileMap = new Map<string, number>()

    let currentScoreRank = 0
    let prevScoreVal = -1
    for (let i = 0; i < scoresSize; i++) {
      const gs = sortedScores[i]
      if (gs.combinedScore !== prevScoreVal) {
        currentScoreRank = i
        prevScoreVal = gs.combinedScore
      }
      const p = scoresSize > 1 ? currentScoreRank / (scoresSize - 1) : 1.0
      combinedPercentileMap.set(gs.tgId, p)
    }

    // 7. Calculate final bell-curve prices and update
    const priceUpdates = []
    for (const gs of golferScores) {
      const p = combinedPercentileMap.get(gs.tgId) ?? 0.0
      const price = computePriceFromPercentile(p, gs.isZeroData)

      const { error: updateError } = await supabaseClient
        .from('tournament_golfers')
        .update({ price })
        .eq('id', gs.tgId)

      if (updateError) {
        console.error(`Error updating price for tournament_golfer ${gs.tgId}: ${updateError.message}`)
      } else {
        priceUpdates.push({ tgId: gs.tgId, price })
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
