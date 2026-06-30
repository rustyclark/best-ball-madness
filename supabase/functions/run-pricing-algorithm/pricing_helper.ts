export function computeGolferPrice(
  golfer: {
    world_rank: number | null;
    wins: number | null;
    top_10s: number | null;
    cuts_made: number | null;
    events_played: number | null;
    rounds_played: number | null;
    scoring_avg: number | null;
    prior_wins: number | null;
    prior_top_10s: number | null;
    prior_cuts_made: number | null;
    prior_events_played: number | null;
    prior_rounds_played: number | null;
    prior_scoring_avg: number | null;
  },
  minAvg: number,
  maxAvg: number,
  relativeWorldRankScore: number,
  N = 8
): { isZeroData: boolean; price: number } {
  const currentEvents = golfer.events_played ?? 0;
  const priorEvents = golfer.prior_events_played ?? 0;
  const hasPriorData = priorEvents > 0;

  // Zero-data flat-fee check
  if (currentEvents === 0 && !hasPriorData) {
    return { isZeroData: true, price: 12.00 };
  }

  const priorWeight = Math.max(0, 1 - currentEvents / N);
  const effectiveEvents = currentEvents + priorWeight * priorEvents;

  const winsRate = ((golfer.wins ?? 0) + priorWeight * (golfer.prior_wins ?? 0)) / (effectiveEvents || 1);
  const top10Rate = ((golfer.top_10s ?? 0) + priorWeight * (golfer.prior_top_10s ?? 0)) / (effectiveEvents || 1);
  const cutsRate = ((golfer.cuts_made ?? 0) + priorWeight * (golfer.prior_cuts_made ?? 0)) / (effectiveEvents || 1);

  const currentRounds = golfer.rounds_played ?? 0;
  const priorRounds = golfer.prior_rounds_played ?? 0;
  const blendedRounds = currentRounds + priorWeight * priorRounds;

  const rawScoringAvg = golfer.scoring_avg && golfer.scoring_avg > 0 ? golfer.scoring_avg : 72.0;
  const rawPriorScoringAvg = golfer.prior_scoring_avg && golfer.prior_scoring_avg > 0 ? golfer.prior_scoring_avg : 72.0;

  let scoringAvg = 72.0; // baseline fallback
  if (blendedRounds > 0) {
    scoringAvg = ((currentRounds * rawScoringAvg) + 
                  (priorWeight * priorRounds * rawPriorScoringAvg)) / blendedRounds;
  } else {
    scoringAvg = rawScoringAvg;
  }

  const clamp = (val: number, min: number, max: number) => Math.max(min, Math.min(max, val));
  const avgRange = maxAvg - minAvg;

  const scoring_avg_score = avgRange > 0 ? clamp((maxAvg - scoringAvg) / avgRange, 0, 1) : 0.5;
  const world_rank_score = clamp(relativeWorldRankScore, 0, 1);
  const wins_score = clamp(winsRate / 0.15, 0, 1);
  const top10_score = clamp(top10Rate / 0.45, 0, 1);
  const cuts_score = clamp(cutsRate, 0, 1);

  const combined = 0.30 * scoring_avg_score + 
                   0.25 * world_rank_score + 
                   0.15 * wins_score + 
                   0.15 * top10_score + 
                   0.15 * cuts_score;

  const minPrice = 12.00;
  const maxPrice = 38.00;
  let price = minPrice + Math.pow(combined, 1.5) * (maxPrice - minPrice);
  price = Math.round(price * 100) / 100; // round to 2 decimal places

  return { isZeroData: false, price };
}
