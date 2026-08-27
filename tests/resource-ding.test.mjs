import assert from "node:assert/strict";
import test from "node:test";
import { source } from "./source.mjs";

test("supports combo-like class resources", () => {
  for (const name of ["ROGUE", "DRUID", "MONK", "PALADIN", "WARLOCK", "MAGE", "EVOKER"]) {
    assert.match(source, new RegExp(`${name} =`));
  }
});

test("dings only on a transition to full", () => {
  assert.match(source, /isFull and not Addon\.wasFull/);
  assert.match(source, /Addon\.wasFull = isFull/);
  assert.match(source, /combatOnly = true/);
});

test("uses event-driven power updates without polling", () => {
  assert.match(source, /UNIT_POWER_FREQUENT/);
  assert.match(source, /UNIT_MAXPOWER/);
  assert.doesNotMatch(source, /C_Timer\.NewTicker/);
});

test("offers auction house and alternative sounds", () => {
  assert.match(source, /AUCTION_WINDOW_OPEN/);
  assert.match(source, /READY_CHECK/);
  assert.match(source, /UI_QUEST_COMPLETE/);
  assert.match(source, /Test sound/);
});
