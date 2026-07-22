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

    // 1. Determine event ID (parse from optional request JSON body)
    let eventId: string | null = null
    const contentLength = req.headers.get("content-length")
    if (contentLength && parseInt(contentLength) > 0) {
      try {
        const body = await req.json()
        if (body && body.event_id) {
          eventId = String(body.event_id)
        }
      } catch (err) {
        console.log("Failed to parse request JSON:", err.message)
      }
    }

    let event = null
    let leaderboardData = null

    if (eventId) {
      console.log(`Fetching specific event ID: ${eventId}`)
      const leaderboardRes = await fetch(`https://site.api.espn.com/apis/site/v2/sports/golf/leaderboard?league=pga&event=${eventId}`)
      if (!leaderboardRes.ok) {
        throw new Error(`Failed to fetch leaderboard for event ID ${eventId}: ${leaderboardRes.statusText}`)
      }
      leaderboardData = await leaderboardRes.json()
      event = leaderboardData.events?.[0]
    } else {
      console.log(`Fetching default active event`)
      const leaderboardRes = await fetch("https://site.api.espn.com/apis/site/v2/sports/golf/leaderboard?league=pga")
      if (!leaderboardRes.ok) {
        throw new Error(`Failed to fetch leaderboard: ${leaderboardRes.statusText}`)
      }
      leaderboardData = await leaderboardRes.json()
      event = leaderboardData.events?.[0]

      // If the default event is completed, scan for the next upcoming event starting this week
      if (event) {
        const rawState = event.status?.type?.name ?? "STATUS_SCHEDULED"
        const isCompleted = rawState === "STATUS_FINAL" || rawState === "STATUS_FINAL_SHORT" || rawState === "STATUS_COMPLETED"
        
        if (isCompleted) {
          console.log(`Default event ${event.name} (${event.id}) is completed. Scanning for upcoming event...`)
          const defaultEventIdStr = event.id
          const defaultEventId = parseInt(defaultEventIdStr)
          
          if (!isNaN(defaultEventId)) {
            // Check next 3 sequential event IDs
            for (let offset = 1; offset <= 3; offset++) {
              const candidateId = String(defaultEventId + offset)
              try {
                console.log(`Checking candidate event ID: ${candidateId}`)
                const candidateRes = await fetch(`https://site.api.espn.com/apis/site/v2/sports/golf/leaderboard?league=pga&event=${candidateId}`)
                if (candidateRes.ok) {
                  const candidateData = await candidateRes.json()
                  const candidateEvent = candidateData.events?.[0]
                  
                  if (candidateEvent) {
                    const candState = candidateEvent.status?.type?.name ?? "STATUS_SCHEDULED"
                    const candIsCompleted = candState === "STATUS_FINAL" || candState === "STATUS_FINAL_SHORT" || candState === "STATUS_COMPLETED"
                    
                    if (!candIsCompleted) {
                      const candDate = new Date(candidateEvent.date)
                      const now = new Date()
                      const diffTime = candDate.getTime() - now.getTime()
                      const diffDays = diffTime / (1000 * 60 * 60 * 24)
                      
                      // If candidate starts within the next 7 days (or started yesterday/today)
                      if (diffDays >= -1 && diffDays <= 7) {
                        console.log(`Found upcoming candidate event: ${candidateEvent.name} (${candidateEvent.id}) starting in ${diffDays.toFixed(1)} days.`)
                        event = candidateEvent
                        leaderboardData = candidateData
                        break
                      }
                    }
                  }
                }
              } catch (err) {
                console.error(`Error checking candidate event ${candidateId}:`, err)
              }
            }
          }
        }
      }
    }

    if (!event) {
      return new Response(JSON.stringify({ message: "No active or upcoming event found on ESPN leaderboard." }), {
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

    const current_round = event.competitions?.[0]?.status?.period ?? event.status?.period ?? 1

    // Course Details
    const courseData = event.courses?.[0]
    const course = courseData?.name ?? "Unknown Course"
    const location = courseData?.address 
      ? `${courseData.address.city}, ${courseData.address.state ?? courseData.address.country ?? ''}`.trim()
      : "Unknown Location"
    const par = courseData?.shotsToPar ?? 72
    const yards = courseData?.totalYards ?? 7000

    const holePars: number[] = []
    if (courseData?.holes && Array.isArray(courseData.holes)) {
      const sortedHoles = [...courseData.holes].sort((a: any, b: any) => (a.number ?? 0) - (b.number ?? 0))
      for (const h of sortedHoles) {
        holePars.push(h.shotsToPar ?? 4)
      }
    }

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
        hole_pars: holePars.length === 18 ? holePars : null,
      }, { onConflict: 'espn_event_id' })
      .select()
      .single()

    if (tError || !tournament) {
      throw new Error(`Tournament upsert failed: ${tError?.message}`)
    }

    // Fetch existing tournament golfers to preserve their prices if running multiple times
    const { data: existingTgs, error: existingTgError } = await supabaseClient
      .from('tournament_golfers')
      .select('golfer_profile_id, price')
      .eq('tournament_id', tournament.id)

    const existingPriceMap = new Map<string, number>()
    if (!existingTgError && existingTgs) {
      for (const tg of existingTgs) {
        existingPriceMap.set(tg.golfer_profile_id, Number(tg.price))
      }
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

    const batchSize = 15;
    for (let i = 0; i < competitors.length; i += batchSize) {
      const batch = competitors.slice(i, i + batchSize);
      await Promise.all(batch.map(async (competitor) => {
        const athlete = competitor.athlete;
        if (!athlete) return;
        const espnId = athlete.id;
        const golferName = athlete.displayName;
        const isAmateur = athlete.amateur === true;

        // Get OWGR rank
        const worldRank = rankMap.get(espnId) ?? null;

        // Fetch stats helper
        const fetchStats = async (year: number) => {
          try {
            const logUrl = `https://sports.core.api.espn.com/v2/sports/golf/athletes/${espnId}/statisticslog?lang=en&region=us`;
            const logRes = await fetch(logUrl);
            let matchingEntries = [];
            if (logRes.ok) {
              const logData = await logRes.json();
              const entries = logData.entries || [];
              matchingEntries = entries.filter((entry: any) => {
                const ref = entry.season?.$ref || '';
                return ref.includes(`/seasons/${year}`);
              });
            }

            let bestStats: Record<string, number> | null = null;
            let maxEvents = -1;

            for (const entry of matchingEntries) {
              if (entry.statistics && entry.statistics.length > 0) {
                const statsUrl = entry.statistics[0].statistics?.$ref?.replace('http://', 'https://');
                if (statsUrl) {
                  try {
                    const statsRes = await fetch(statsUrl);
                    if (statsRes.ok) {
                      const statsData = await statsRes.json();
                      const flatStats: Record<string, number> = {};
                      const categories = statsData.splits?.categories ?? statsData.categories ?? [];
                      for (const cat of categories) {
                        const stats = cat.stats ?? cat.statistics ?? [];
                        for (const stat of stats) {
                          if (stat.name && typeof stat.value === 'number') {
                            flatStats[stat.name] = stat.value;
                          }
                        }
                      }
                      
                      // Sanitize and logically correct tournamentsPlayed and roundsPlayed
                      const cutsMade = flatStats['cutsMade'] ? Math.round(flatStats['cutsMade']) : 0;
                      const wins = flatStats['wins'] ? Math.round(flatStats['wins']) : 0;
                      const top10s = flatStats['topTenFinishes'] ? Math.round(flatStats['topTenFinishes']) : 0;
                      let eventsPlayed = flatStats['tournamentsPlayed'] ? Math.round(flatStats['tournamentsPlayed']) : 0;
                      eventsPlayed = Math.max(eventsPlayed, cutsMade, wins, top10s);
                      
                      let roundsPlayed = flatStats['roundsPlayed'] ? Math.round(flatStats['roundsPlayed']) : 0;
                      roundsPlayed = Math.max(roundsPlayed, eventsPlayed * 2);
                      
                      flatStats['tournamentsPlayed'] = eventsPlayed;
                      flatStats['roundsPlayed'] = roundsPlayed;

                      if (eventsPlayed > maxEvents) {
                        maxEvents = eventsPlayed;
                        bestStats = flatStats;
                      }
                    }
                  } catch {
                    // Ignore and try next
                  }
                }
              }
            }

            if (bestStats) {
              return bestStats;
            }

            const fallbackUrl = `https://sports.core.api.espn.com/v2/sports/golf/leagues/pga/seasons/${year}/types/2/athletes/${espnId}/statistics`;
            const statsRes = await fetch(fallbackUrl);
            if (!statsRes.ok) return null;
            const statsData = await statsRes.json();
            
            const flatStats: Record<string, number> = {};
            const categories = statsData.splits?.categories ?? statsData.categories ?? [];
            for (const cat of categories) {
              const stats = cat.stats ?? cat.statistics ?? [];
              for (const stat of stats) {
                if (stat.name && typeof stat.value === 'number') {
                  flatStats[stat.name] = stat.value;
                }
              }
            }
            
            // Sanitize and logically correct fallback stats
            const cutsMade = flatStats['cutsMade'] ? Math.round(flatStats['cutsMade']) : 0;
            const wins = flatStats['wins'] ? Math.round(flatStats['wins']) : 0;
            const top10s = flatStats['topTenFinishes'] ? Math.round(flatStats['topTenFinishes']) : 0;
            let eventsPlayed = flatStats['tournamentsPlayed'] ? Math.round(flatStats['tournamentsPlayed']) : 0;
            eventsPlayed = Math.max(eventsPlayed, cutsMade, wins, top10s);
            
            let roundsPlayed = flatStats['roundsPlayed'] ? Math.round(flatStats['roundsPlayed']) : 0;
            roundsPlayed = Math.max(roundsPlayed, eventsPlayed * 2);
            
            flatStats['tournamentsPlayed'] = eventsPlayed;
            flatStats['roundsPlayed'] = roundsPlayed;

            return flatStats;
          } catch {
            return null;
          }
        };

        // Fetch current-season & prior-season stats
        const currentStats = await fetchStats(currentYear);
        const priorStats = await fetchStats(currentYear - 1);

        // Sanitize scoring averages (must be > 0)
        const cleanScoringAvg = (currentStats && currentStats['scoringAverage'] && currentStats['scoringAverage'] > 0) ? currentStats['scoringAverage'] : null;
        const cleanPriorScoringAvg = (priorStats && priorStats['scoringAverage'] && priorStats['scoringAverage'] > 0) ? priorStats['scoringAverage'] : null;

        // 5. Upsert golfer profile
        const profileData = {
          espn_id: espnId,
          name: golferName,
          world_rank: worldRank,
          is_amateur: isAmateur,
          scoring_avg: cleanScoringAvg,
          wins: currentStats?.['wins'] ? Math.round(currentStats['wins']) : 0,
          top_10s: currentStats?.['topTenFinishes'] ? Math.round(currentStats['topTenFinishes']) : 0,
          cuts_made: currentStats?.['cutsMade'] ? Math.round(currentStats['cutsMade']) : 0,
          events_played: currentStats?.['tournamentsPlayed'] ? Math.round(currentStats['tournamentsPlayed']) : 0,
          rounds_played: currentStats?.['roundsPlayed'] ? Math.round(currentStats['roundsPlayed']) : 0,
          
          prior_scoring_avg: cleanPriorScoringAvg,
          prior_wins: priorStats?.['wins'] ? Math.round(priorStats['wins']) : 0,
          prior_top_10s: priorStats?.['topTenFinishes'] ? Math.round(priorStats['topTenFinishes']) : 0,
          prior_cuts_made: priorStats?.['cutsMade'] ? Math.round(priorStats['cutsMade']) : 0,
          prior_events_played: priorStats?.['tournamentsPlayed'] ? Math.round(priorStats['tournamentsPlayed']) : 0,
          prior_rounds_played: priorStats?.['roundsPlayed'] ? Math.round(priorStats['roundsPlayed']) : 0,
          updated_at: new Date().toISOString(),
        };

        const { data: profile, error: pError } = await supabaseClient
          .from('golfer_profiles')
          .upsert(profileData, { onConflict: 'espn_id' })
          .select()
          .single();

        if (pError || !profile) {
          console.error(`Error upserting golfer ${golferName}: ${pError?.message}`);
          return;
        }

        // 6. Upsert tournament_golfer row
        const tgStatus = competitor.status?.type?.name === "STATUS_CUT" ? "MC" : 
                         competitor.status?.type?.name === "STATUS_WITHDRAWN" ? "WD" : "ACTIVE";

        const existingPrice = existingPriceMap.get(profile.id);
        const priceToSet = existingPrice !== undefined ? existingPrice : 20.00;

        const { data: tgRow, error: tgError } = await supabaseClient
          .from('tournament_golfers')
          .upsert({
            tournament_id: tournament.id,
            golfer_profile_id: profile.id,
            price: priceToSet,
            status: tgStatus,
          }, { onConflict: 'tournament_id,golfer_profile_id' })
          .select()
          .single();

        if (tgError) {
          console.error(`Error linking golfer ${golferName} to tournament: ${tgError.message}`);
        } else {
          results.push({
            name: golferName,
            profile_id: profile.id,
            tournament_golfer_id: tgRow.id,
          });
        }
      }));
    }

    // Check if tournament field is finalized on ESPN
    if (competitors.length === 0) {
      console.log(`Tournament field not finalized yet on ESPN for event ${espnEventId} (${name}). Skipping field ingestion & pricing until next hourly run.`)
      return new Response(
        JSON.stringify({
          message: "Tournament field has not been finalized yet on ESPN. Please check back soon.",
          tournament: tournament.name,
          golfers_ingested: 0,
          field_finalized: false,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    // 7. Clean up non-entrants: mark any tournament_golfers for this tournament that were not in the fetched field as WD (withdrawn)
    const activeTgIds = results.map(r => r.tournament_golfer_id)
    if (activeTgIds.length > 0) {
      const { error: updateError } = await supabaseClient
        .from('tournament_golfers')
        .update({ status: 'WD' })
        .eq('tournament_id', tournament.id)
        .not('id', 'in', `(${activeTgIds.join(',')})`)

      if (updateError) {
        console.error(`Error cleaning up non-entrants: ${updateError.message}`)
      } else {
        console.log(`Successfully marked non-entrants as WD for tournament ${tournament.id}`)
      }
    }

    // 8. Trigger pricing algorithm run to set dynamic prices immediately
    let pricingMessage = "Pricing run not triggered."
    try {
      const pricingRes = await fetch(
        `${Deno.env.get('SUPABASE_URL')}/functions/v1/run-pricing-algorithm`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          },
          body: JSON.stringify({}),
        }
      )
      if (!pricingRes.ok) {
        console.error(`Failed to trigger pricing algorithm: ${pricingRes.statusText}`)
        pricingMessage = `Failed to trigger pricing: ${pricingRes.statusText}`
      } else {
        const pricingData = await pricingRes.json()
        console.log(`Successfully triggered pricing algorithm: ${JSON.stringify(pricingData)}`)
        pricingMessage = `Pricing run triggered successfully. priced: ${pricingData.golfers_priced}`
      }
    } catch (pricingErr) {
      console.error(`Failed to trigger pricing algorithm: ${pricingErr.message}`)
      pricingMessage = `Failed to trigger pricing: ${pricingErr.message}`
    }

    return new Response(
      JSON.stringify({ 
        message: "Tournament field ingestion completed.", 
        tournament: tournament.name,
        golfers_ingested: results.length,
        golfers_active: activeTgIds.length,
        field_finalized: true,
        pricing: pricingMessage
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
