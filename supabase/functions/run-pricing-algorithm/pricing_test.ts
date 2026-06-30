import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts"
import { computeGolferPrice } from "./pricing_helper.ts"

Deno.test("computeGolferPrice - zero data golfer", () => {
  const golfer = {
    world_rank: null,
    wins: null,
    top_10s: null,
    cuts_made: null,
    events_played: 0,
    rounds_played: 0,
    scoring_avg: null,
    prior_wins: null,
    prior_top_10s: null,
    prior_cuts_made: null,
    prior_events_played: 0,
    prior_rounds_played: 0,
    prior_scoring_avg: null,
  };

  const result = computeGolferPrice(golfer, 68, 74, 0.5);
  assertEquals(result.isZeroData, true);
  assertEquals(result.combinedScore, 0.0);
});

Deno.test("computeGolferPrice - premium golfer", () => {
  const golfer = {
    world_rank: 1,
    wins: 3,
    top_10s: 8,
    cuts_made: 10,
    events_played: 10,
    rounds_played: 40,
    scoring_avg: 68.2,
    prior_wins: 4,
    prior_top_10s: 9,
    prior_cuts_made: 12,
    prior_events_played: 12,
    prior_rounds_played: 48,
    prior_scoring_avg: 68.5,
  };

  const result = computeGolferPrice(golfer, 68.2, 74.0, 0.99);
  assertEquals(result.isZeroData, false);
  assertEquals(result.combinedScore >= 0.0 && result.combinedScore <= 1.0, true);
  assertEquals(result.combinedScore > 0.70, true);
});

Deno.test("computeGolferPrice - low rank golfer", () => {
  const golfer = {
    world_rank: 100,
    wins: 0,
    top_10s: 0,
    cuts_made: 1,
    events_played: 5,
    rounds_played: 12,
    scoring_avg: 74.0,
    prior_wins: 0,
    prior_top_10s: 0,
    prior_cuts_made: 2,
    prior_events_played: 6,
    prior_rounds_played: 16,
    prior_scoring_avg: 73.5,
  };

  const result = computeGolferPrice(golfer, 68.2, 74.0, 0.0);
  assertEquals(result.isZeroData, false);
  assertEquals(result.combinedScore >= 0.0 && result.combinedScore <= 1.0, true);
  assertEquals(result.combinedScore < 0.30, true);
});
