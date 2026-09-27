import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { source } from "./source.mjs";

const settings = fs.readFileSync(
  path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "Settings.lua"), "utf8");

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

test("does not tell casters they stay silent", () => {
  // the mana and Soul Shard sounds are for classes without a finisher resource
  assert.doesNotMatch(source, /stay silent/);
  assert.doesNotMatch(source, /No supported resource/);
});

test("no full-width line runs into the right-hand column", () => {
  // The right-hand column starts at y = -102. A line anchored to the panel's right edge below that
  // runs under the column's controls: the "Supported:" note did, under the mana slider.
  const fullWidth = [...settings.matchAll(/SetPoint\("TOPRIGHT", -?\d+, (-?\d+)\)/g)];
  assert.ok(fullWidth.length > 0, "the subtitle, at least, is full width");
  for (const [line, y] of fullWidth) {
    assert.ok(Number(y) > -102, `${line} reaches the right-hand column`);
  }
});
