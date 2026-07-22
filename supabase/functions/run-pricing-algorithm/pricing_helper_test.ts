import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { computeGolferPrice, computePriceFromPercentile } from "./pricing_helper.ts";

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

  const result = computeGolferPrice(zeroDataGolfer, 68.0, 74.0, 0.5);
  assertEquals(result.isZeroData, true);
  assertEquals(result.combinedScore, 0.0);
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

  const result = computeGolferPrice(unrankedGolfer, 68.0, 74.0, 0.0);
  assertEquals(result.isZeroData, false);
  assertEquals(result.combinedScore >= 0.0 && result.combinedScore <= 1.0, true);
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

  const result = computeGolferPrice(golfer, 68.0, 74.0, 0.99);
  assertEquals(result.isZeroData, false);
  assertEquals(result.combinedScore >= 0.0 && result.combinedScore <= 1.0, true);
  assertEquals(result.combinedScore > 0.50, true);
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
    prior_events_played: 5, // Has 5 prior events, so not zero/low data, but events_played is 0
    prior_rounds_played: 0, // 0 rounds
    prior_scoring_avg: 73.0,
  };

  const result = computeGolferPrice(weirdGolfer, 68.0, 74.0, 0.90);
  assertEquals(result.isZeroData, false);
  assertEquals(result.combinedScore >= 0.0 && result.combinedScore <= 1.0, true);
});

Deno.test("Pricing Helper - Low Data Player Default", () => {
  const lowDataGolfer = {
    world_rank: 50,
    wins: 0,
    top_10s: 0,
    cuts_made: 1,
    events_played: 1,
    rounds_played: 4,
    scoring_avg: 70.0,
    prior_wins: 0,
    prior_top_10s: 0,
    prior_cuts_made: 0,
    prior_events_played: 2,
    prior_rounds_played: 8,
    prior_scoring_avg: 71.0,
  }; // total events = 3 < 5

  const result = computeGolferPrice(lowDataGolfer, 68.0, 74.0, 0.5);
  assertEquals(result.isZeroData, true);
  assertEquals(result.combinedScore, 0.0);
});

Deno.test("Pricing Helper - computePriceFromPercentile distribution", () => {
  // Zero data case returns minimum price 12.00
  assertEquals(computePriceFromPercentile(0.5, true), 12.00);

  // Top 1% (p=1.0) returns max price 38.00
  assertEquals(computePriceFromPercentile(1.0, false), 38.00);

  // Top 5% (p=0.95) returns ~37.55
  assertEquals(computePriceFromPercentile(0.95, false), 37.55);

  // Top 20% (11-33% tier, p=0.80) returns 31.98
  assertEquals(computePriceFromPercentile(0.80, false), 31.98);

  // Top 50% (33-66% tier, p=0.50) returns 16.94
  assertEquals(computePriceFromPercentile(0.50, false), 16.94);

  // Bottom 0% (p=0.0) returns min price 12.00
  assertEquals(computePriceFromPercentile(0.0, false), 12.00);
});

