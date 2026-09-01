-- Run from the addon root:  lua tests/opener.test.lua
--
-- A rogue opening from stealth got no ding.
--
-- "Combat only" is on by default, and it was doing two jobs where it should
-- have done one: it skipped the sound, and it also recorded the full bar as
-- already announced. Ambush and Cheap Shot award their combo points in the same
-- instant the fight starts, and UnitAffectingCombat is routinely still false
-- when the event arrives. So the addon saw a full bar, said nothing because
-- combat had not registered yet, and marked it announced. The fight then began
-- with the points already there and nothing left to announce -- which is the
-- fight starting on four points and the fifth passing in silence.
--
-- Skipping the sound is right. Consuming the transition is not.

local played, registered, combat, points

local function client(opts)
  opts = opts or {}
  played, registered = {}, {}
  combat = opts.combat or false
  points = opts.points or 0
  for _, name in ipairs({ "Enum", "SOUNDKIT", "GetComboPoints", "MAX_COMBO_POINTS",
                          "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "ResourceDingDB" }) do
    _G[name] = nil
  end
  WOW_PROJECT_MAINLINE, WOW_PROJECT_ID = 1, 1        -- Retail
  Enum = { PowerType = { ComboPoints = 4, Chi = 12, HolyPower = 9,
                         SoulShards = 7, ArcaneCharges = 16, Essence = 19 } }
  SOUNDKIT = { AUCTION_WINDOW_OPEN = 5274, READY_CHECK = 8960, UI_QUEST_COMPLETE = 878,
               LEVEL_UP = 888, LOOT_MONEY_COINS = 120, RAID_WARNING = 8959,
               UI_ORDERHALL_TALENT_READY_TOAST = 73743 }

  local frame = {}
  function frame:RegisterEvent(event) registered[event] = true end
  function frame:RegisterUnitEvent(event) registered[event] = true end
  function frame:SetScript(_, fn) frame.fn = fn end
  CreateFrame = function() return frame end
  C_Timer = { After = function(_, fn) if fn then fn() end end }
  SlashCmdList = {}
  strlower, strtrim = string.lower, function(s) return (tostring(s):gsub("^%s+",""):gsub("%s+$","")) end
  UnitClass = function() return "Rogue", "ROGUE" end
  UnitAffectingCombat = function() return combat end
  PlaySound = function(id) played[#played + 1] = id return true end
  UnitPower = function() return points end
  UnitPowerMax = function() return 5 end
  GetComboPoints = function() error("Retail must not read combo points off the target") end

  local chunk = assert(loadfile("Core.lua"))
  chunk("ResourceDing", {})
  local addon = _G.ResourceDing
  frame.fn(nil, "ADDON_LOADED", "ResourceDing")
  return addon, frame
end

-- The event the fight itself fires has to be listened for, or nothing rechecks
-- the bar at the moment combat begins.
local addon, frame = client()
assert(registered.PLAYER_REGEN_DISABLED,
  "entering combat must be watched: the bar can fill just before it")

-- The reported bug, played out in order.
addon, frame = client{ combat = false, points = 4 }
frame.fn(nil, "UNIT_POWER_UPDATE", "player")
assert(#played == 0, "four of five is not full; nothing to announce yet")

points = 5                                    -- the opener lands...
frame.fn(nil, "UNIT_POWER_UPDATE", "player")  -- ...and combat has not registered
assert(#played == 0, "with combat-only set, a full bar out of combat stays silent")

combat = true                                 -- the fight starts a moment later
frame.fn(nil, "PLAYER_REGEN_DISABLED")
assert(#played == 1,
  "the ding belongs here: the bar is full and the fight has begun, got " .. #played)

-- And it must not then repeat on every event while it stays full.
frame.fn(nil, "UNIT_POWER_UPDATE", "player")
frame.fn(nil, "UNIT_POWER_FREQUENT", "player")
assert(#played == 1, "a bar that stays full is announced once, got " .. #played)

-- Spending and refilling inside the fight announces again.
points = 0
frame.fn(nil, "UNIT_POWER_UPDATE", "player")
points = 5
frame.fn(nil, "UNIT_POWER_UPDATE", "player")
assert(#played == 2, "refilling in combat is a fresh ding, got " .. #played)

-- Loading with the bar already full is not a rise, and announces nothing. There
-- was no moment of filling for the addon to have missed.
addon, frame = client{ combat = true, points = 5 }
frame.fn(nil, "UNIT_POWER_UPDATE", "player")
assert(#played == 0, "a bar that was already full at load has nothing to announce")

-- With combat-only off, filling out of combat announces there and then.
addon, frame = client{ combat = false, points = 4 }
addon.db.combatOnly = false
points = 5
frame.fn(nil, "UNIT_POWER_UPDATE", "player")
assert(#played == 1, "with combat-only off a full bar announces out of combat too")

-- Turned off entirely, nothing sounds and nothing is left queued to sound later.
addon, frame = client{ combat = false, points = 4 }
addon.db.enabled = false
points = 5
frame.fn(nil, "UNIT_POWER_UPDATE", "player")
combat = true
frame.fn(nil, "PLAYER_REGEN_DISABLED")
assert(#played == 0, "disabled means silent, in combat as well as out of it")

-- A Retail druid out of cat form has no combo bar: UnitPowerMax reports zero.
-- The Classic fallback reads combo points off the *target*, and letting a Retail
-- client reach it reported a bar that spec does not have -- and called an API the
-- repo's own test says Retail must never call.
addon, frame = client{ combat = true, points = 0 }
UnitPowerMax = function() return 0 end
local ok, err = pcall(function() return addon.GetResourceState() end)
assert(ok, "a Retail druid with no combo bar must not reach the Classic path: " .. tostring(err))
local _, current, maximum = addon.GetResourceState()
assert(maximum == 0,
  "with no bar the maximum stays zero rather than being forced to five, got " .. tostring(maximum))

print("opener: ok")
