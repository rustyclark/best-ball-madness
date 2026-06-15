import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { computeGolferPrice } from "./pricing_helper.ts";

Deno.test("Pricing Helper - Zero Data Default", () => {
  const zeroDataGolfer = {
    world_rank: null,
    wins: null,
    top_10s: null,
    cuts_made: null,
    events_played: 0,
    rounds_played: null,
    scoring_avg: null,
    prior_wins: null,
    prior_top_10s: null,
    prior_cuts_made: null,
    prior_events_played: 0,
    prior_rounds_played: null,
    prior_scoring_avg: null,
  };

  const result = computeGolferPrice(zeroDataGolfer, 68.0, 74.0);
  assertEquals(result.isZeroData, true);
  assertEquals(result.price, 20.00);
});

Deno.test("Pricing Helper - Unranked Player Default", () => {
  const unrankedGolfer = {
    world_rank: null, // Should default to rank 100
    wins: 0,
    top_10s: 0,
    cuts_made: 2,
    events_played: 4,
    rounds_played: 8,
    scoring_avg: 72.0,
    prior_wins: 0,
    prior_top_10s: 1,
    prior_cuts_made: 4,
    prior_events_played: 8,
    prior_rounds_played: 16,
    prior_scoring_avg: 71.5,
  };

  const result = computeGolferPrice(unrankedGolfer, 68.0, 74.0);
  assertEquals(result.isZeroData, false);
  // Unranked should be treated as world rank 100.
  // We check that price is computed within valid range
  assertEquals(result.price >= 19.00 && result.price <= 31.00, true);
});

Deno.test("Pricing Helper - Blended Model logic", () => {
  const golfer = {
    world_rank: 1,
    wins: 2,
    top_10s: 3,
    cuts_made: 4,
    events_played: 4, // N = 8, so priorWeight = 1 - 4/8 = 0.5
    rounds_played: 16,
    scoring_avg: 68.0,
    prior_wins: 4,
    prior_top_10s: 6,
    prior_cuts_made: 8,
    prior_events_played: 12,
    prior_rounds_played: 48,
    prior_scoring_avg: 69.0,
  };

  const result = computeGolferPrice(golfer, 68.0, 74.0);
  assertEquals(result.isZeroData, false);
  assertEquals(result.price >= 19.00 && result.price <= 31.00, true);
  // High rank, low scoring average, wins -> price should be at the higher end
  assertEquals(result.price > 25.00, true);
});

Deno.test("Pricing Helper - Denominator Guards", () => {
  const weirdGolfer = {
    world_rank: 10,
    wins: 0,
    top_10s: 0,
    cuts_made: 0,
    events_played: 0,
    rounds_played: 0,
    scoring_avg: null,
    prior_wins: 0,
    prior_top_10s: 0,
    prior_cuts_made: 0,
    prior_events_played: 1, // Has 1 prior event, so not zero data, but events_played is 0
    prior_rounds_played: 0, // 0 rounds
    prior_scoring_avg: 73.0,
  };

  const result = computeGolferPrice(weirdGolfer, 68.0, 74.0);
  assertEquals(result.isZeroData, false);
  assertEquals(result.price >= 19.00 && result.price <= 31.00, true);
});
