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

    // 1. Get all golfer profiles from our database
    const { data: golfers, error: gError } = await supabaseClient
      .from('golfer_profiles')
      .select('id, espn_id, name')

    if (gError || !golfers || golfers.length === 0) {
      throw new Error(`Failed to load golfer profiles: ${gError?.message || 'None found'}`)
    }

    const currentYear = new Date().getFullYear()

    // 2. Fetch the latest OWGR Top 100 Rankings
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

    let updatedCount = 0;
    const batchSize = 15;
    for (let i = 0; i < golfers.length; i += batchSize) {
      const batch = golfers.slice(i, i + batchSize);
      await Promise.all(batch.map(async (golfer) => {
        const espnId = golfer.espn_id;
        const worldRank = rankMap.get(espnId) ?? null;

        // Fetch current-season statistics
        try {
          const statsRes = await fetch(`https://sports.core.api.espn.com/v2/sports/golf/leagues/pga/seasons/${currentYear}/types/2/athletes/${espnId}/statistics`);
          if (!statsRes.ok) {
            // If no current season statistics, just update world rank
            await supabaseClient
              .from('golfer_profiles')
              .update({ world_rank: worldRank })
              .eq('id', golfer.id);
            return;
          }
          
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

          const cleanScoringAvg = (flatStats['scoringAverage'] && flatStats['scoringAverage'] > 0) ? flatStats['scoringAverage'] : null;

          // Update current-season stats only
          await supabaseClient
            .from('golfer_profiles')
            .update({
              world_rank: worldRank,
              scoring_avg: cleanScoringAvg,
              wins: flatStats['wins'] ? Math.round(flatStats['wins']) : 0,
              top_10s: flatStats['topTenFinishes'] ? Math.round(flatStats['topTenFinishes']) : 0,
              cuts_made: flatStats['cutsMade'] ? Math.round(flatStats['cutsMade']) : 0,
              events_played: flatStats['tournamentsPlayed'] ? Math.round(flatStats['tournamentsPlayed']) : 0,
              rounds_played: flatStats['roundsPlayed'] ? Math.round(flatStats['roundsPlayed']) : 0,
              updated_at: new Date().toISOString(),
            })
            .eq('id', golfer.id);

          updatedCount++;
        } catch (e) {
          console.error(`Failed to update statistics for golfer ${golfer.name} (${golfer.id}): ${e.message}`);
        }
      }));
    }

    return new Response(
      JSON.stringify({
        message: "Golfer statistics updated successfully.",
        golfers_updated: updatedCount,
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
