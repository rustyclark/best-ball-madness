import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.21.0"

serve(async (req) => {
  // CORS Headers
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

    // 1. Fetch active PGA event from ESPN Leaderboard
    const leaderboardRes = await fetch("https://site.api.espn.com/apis/site/v2/sports/golf/leaderboard?league=pga")
    if (!leaderboardRes.ok) {
      throw new Error(`Failed to fetch leaderboard: ${leaderboardRes.statusText}`)
    }
    const leaderboardData = await leaderboardRes.json()
    const event = leaderboardData.events?.[0]
    if (!event) {
      return new Response(JSON.stringify({ message: "No active event found on ESPN leaderboard." }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const espnEventId = event.id
    const name = event.name
    const startDateStr = event.date // "2026-06-11T12:06Z"
    const endDateStr = event.endDate // "2026-06-14T22:00Z"
    const start_date = startDateStr ? startDateStr.split('T')[0] : new Date().toISOString().split('T')[0]
    const end_date = endDateStr ? endDateStr.split('T')[0] : new Date().toISOString().split('T')[0]

    // ESPN state parsing
    const rawState = event.status?.type?.name ?? "STATUS_SCHEDULED"
    let status = "SCHEDULED"
    if (rawState === "STATUS_IN_PROGRESS") {
      status = "IN_PROGRESS"
    } else if (rawState === "STATUS_SUSPENDED") {
      status = "SUSPENDED"
    } else if (rawState === "STATUS_FINAL" || rawState === "STATUS_FINAL_SHORT" || rawState === "STATUS_COMPLETED") {
      status = "COMPLETED"
    }

    const current_round = event.status?.period ?? 1

    // Course Details
    const courseData = event.courses?.[0]
    const course = courseData?.name ?? "Unknown Course"
    const location = courseData?.address 
      ? `${courseData.address.city}, ${courseData.address.state ?? courseData.address.country ?? ''}`.trim()
      : "Unknown Location"
    const par = courseData?.shotsToPar ?? 72
    const yards = courseData?.totalYards ?? 7000

    // 2. Upsert tournament into public.tournaments
    const { data: tournament, error: tError } = await supabaseClient
      .from('tournaments')
      .upsert({
        espn_event_id: espnEventId,
        name,
        course,
        location,
        par,
        yards,
        start_date,
        end_date,
        status,
        current_round,
      }, { onConflict: 'espn_event_id' })
      .select()
      .single()

    if (tError || !tournament) {
      throw new Error(`Tournament upsert failed: ${tError?.message}`)
    }

    // 3. Fetch OWGR Top 100 Rankings to match with players
    const currentYear = new Date(start_date).getFullYear()
    const rankingsRes = await fetch(`https://sports.core.api.espn.com/v2/sports/golf/leagues/all/seasons/${currentYear}/rankings/1`)
    const rankMap = new Map<string, number>()
    if (rankingsRes.ok) {
      const rankingsData = await rankingsRes.json()
      const latestRankingsRef = rankingsData.rankings?.[0]?.$ref
      if (latestRankingsRef) {
        const latestRankingsRes = await fetch(latestRankingsRef)
        if (latestRankingsRes.ok) {
          const latestRankingsData = await latestRankingsRes.json()
          for (const rankItem of latestRankingsData.ranks || []) {
            const athleteRef = rankItem.athlete?.$ref
            if (athleteRef) {
              const parts = athleteRef.split('/')
              const athleteId = parts[parts.length - 1]?.split('?')[0]
              if (athleteId) {
                rankMap.set(athleteId, rankItem.current)
              }
            }
          }
        }
      }
    }

    // 4. Ingest Competitors (Field)
    const competitors = event.competitions?.[0]?.competitors || []
    const results = []

    for (const competitor of competitors) {
      const athlete = competitor.athlete
      if (!athlete) continue
      const espnId = athlete.id
      const golferName = athlete.displayName

      // Get OWGR rank
      const worldRank = rankMap.get(espnId) ?? null

      // Fetch stats helper
      const fetchStats = async (year: number) => {
        try {
          const statsRes = await fetch(`https://sports.core.api.espn.com/v2/sports/golf/leagues/pga/seasons/${year}/types/2/athletes/${espnId}/statistics`)
          if (!statsRes.ok) return null
          const statsData = await statsRes.json()
          
          const flatStats: Record<string, number> = {}
          const categories = statsData.splits?.categories ?? statsData.categories ?? []
          for (const cat of categories) {
            const stats = cat.stats ?? cat.statistics ?? []
            for (const stat of stats) {
              if (stat.name && typeof stat.value === 'number') {
                flatStats[stat.name] = stat.value
              }
            }
          }
          return flatStats;
        } catch {
          return null
        }
      }

      // Fetch current-season & prior-season stats
      const currentStats = await fetchStats(currentYear)
      const priorStats = await fetchStats(currentYear - 1)

      // 5. Upsert golfer profile
      const profileData = {
        espn_id: espnId,
        name: golferName,
        world_rank: worldRank,
        scoring_avg: currentStats?.['scoringAverage'] ?? null,
        wins: currentStats?.['wins'] ? Math.round(currentStats['wins']) : 0,
        top_10s: currentStats?.['topTenFinishes'] ? Math.round(currentStats['topTenFinishes']) : 0,
        cuts_made: currentStats?.['cutsMade'] ? Math.round(currentStats['cutsMade']) : 0,
        events_played: currentStats?.['tournamentsPlayed'] ? Math.round(currentStats['tournamentsPlayed']) : 0,
        rounds_played: currentStats?.['roundsPlayed'] ? Math.round(currentStats['roundsPlayed']) : 0,
        
        prior_scoring_avg: priorStats?.['scoringAverage'] ?? null,
        prior_wins: priorStats?.['wins'] ? Math.round(priorStats['wins']) : 0,
        prior_top_10s: priorStats?.['topTenFinishes'] ? Math.round(priorStats['topTenFinishes']) : 0,
        prior_cuts_made: priorStats?.['cutsMade'] ? Math.round(priorStats['cutsMade']) : 0,
        prior_events_played: priorStats?.['tournamentsPlayed'] ? Math.round(priorStats['tournamentsPlayed']) : 0,
        prior_rounds_played: priorStats?.['roundsPlayed'] ? Math.round(priorStats['roundsPlayed']) : 0,
        updated_at: new Date().toISOString(),
      }

      const { data: profile, error: pError } = await supabaseClient
        .from('golfer_profiles')
        .upsert(profileData, { onConflict: 'espn_id' })
        .select()
        .single()

      if (pError || !profile) {
        console.error(`Error upserting golfer ${golferName}: ${pError?.message}`)
        continue
      }

      // 6. Upsert tournament_golfer row
      // We set price to 20.00 by default; pricing algorithm will adjust it Wednesday evening.
      const tgStatus = competitor.status?.type?.name === "STATUS_CUT" ? "MC" : 
                       competitor.status?.type?.name === "STATUS_WITHDRAWN" ? "WD" : "ACTIVE";

      const { data: tgRow, error: tgError } = await supabaseClient
        .from('tournament_golfers')
        .upsert({
          tournament_id: tournament.id,
          golfer_profile_id: profile.id,
          price: 20.00, // default baseline
          status: tgStatus,
        }, { onConflict: 'tournament_id,golfer_profile_id' })
        .select()
        .single()

      if (tgError) {
        console.error(`Error linking golfer ${golferName} to tournament: ${tgError.message}`)
      } else {
        results.push({
          name: golferName,
          profile_id: profile.id,
          tournament_golfer_id: tgRow.id,
        })
      }
    }

    // 7. Clean up non-entrants: delete any tournament_golfers for this tournament that were not in the fetched field
    const activeTgIds = results.map(r => r.tournament_golfer_id)
    if (activeTgIds.length > 0) {
      const { error: deleteError } = await supabaseClient
        .from('tournament_golfers')
        .delete()
        .eq('tournament_id', tournament.id)
        .not('id', 'in', `(${activeTgIds.join(',')})`)

      if (deleteError) {
        console.error(`Error cleaning up non-entrants: ${deleteError.message}`)
      } else {
        console.log(`Successfully cleaned up non-entrants for tournament ${tournament.id}`)
      }
    }

    return new Response(
      JSON.stringify({ 
        message: "Tournament field ingestion completed.", 
        tournament: tournament.name,
        golfers_ingested: results.length,
        golfers_active: activeTgIds.length
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
