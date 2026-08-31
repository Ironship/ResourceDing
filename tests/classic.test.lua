-- Run from the addon root:  lua tests/classic.test.lua
--
-- Written without a Classic client to try it on, so this stands in for one. It
-- loads Core.lua twice: once against a fake Retail API and once against a fake
-- Classic Era one, and checks the three places the two games disagree.
--
-- The first is the one that matters most. Registering an event the client does
-- not have raises an error, and that happens while the addon is loading -- so a
-- single absent name does not cost a feature, it takes the whole addon down
-- before it has done anything. Classic Era has no specialisations and therefore
-- no PLAYER_SPECIALIZATION_CHANGED.

local registered, played

local function stubClient(opts)
  registered, played = {}, {}
  for _, name in ipairs({ "Enum", "SOUNDKIT", "GetComboPoints", "MAX_COMBO_POINTS",
                          "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "ResourceDingDB" }) do
    _G[name] = nil
  end

  WOW_PROJECT_MAINLINE = 1
  WOW_PROJECT_ID = opts.classic and 2 or 1

  Enum = { PowerType = { ComboPoints = 4, Chi = 12, HolyPower = 9,
                         SoulShards = 7, ArcaneCharges = 16, Essence = 19 } }

  SOUNDKIT = { AUCTION_WINDOW_OPEN = 5274, READY_CHECK = 8960, UI_QUEST_COMPLETE = 878,
               LEVEL_UP = 888, LOOT_MONEY_COINS = 120, RAID_WARNING = 8959 }
  -- A Legion sound. The Classic client has never heard of it.
  if not opts.classic then SOUNDKIT.UI_ORDERHALL_TALENT_READY_TOAST = 73743 end

  local known = {
    ADDON_LOADED = true, PLAYER_ENTERING_WORLD = true, UPDATE_SHAPESHIFT_FORM = true,
    PLAYER_TARGET_CHANGED = true, UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true,
    UNIT_MAXPOWER = true, PLAYER_REGEN_DISABLED = true,
  }
  if opts.classic then
    known.UNIT_COMBO_POINTS = true
  else
    known.PLAYER_SPECIALIZATION_CHANGED = true
  end

  local frame = {}
  function frame:RegisterEvent(event)
    if not known[event] then error("Attempted to register unknown event: " .. event) end
    registered[event] = true
  end
  function frame:RegisterUnitEvent(event, unit)
    if not known[event] then error("Attempted to register unknown event: " .. event) end
    registered[event] = true
  end
  function frame:SetScript(_, fn) frame.fn = fn end
  CreateFrame = function() return frame end

  C_Timer = { After = function(_, fn) if fn then fn() end end }
  SlashCmdList = {}
  strlower, strtrim = string.lower, function(s) return (tostring(s):gsub("^%s+",""):gsub("%s+$","")) end
  UnitClass = function() return "Rogue", opts.class or "ROGUE" end
  UnitAffectingCombat = function() return true end
  PlaySound = function(id) played[#played + 1] = id; return true end
  UnitPower = function() return opts.power or 0 end
  UnitPowerMax = function() return opts.maxPower or 0 end
  if opts.classic then
    MAX_COMBO_POINTS = 5
    comboNow = opts.combo or 0
    GetComboPoints = function() return comboNow end
  else
    -- Retail must never fall back to this; if it does, say so loudly.
    GetComboPoints = function() error("Retail must not read combo points off the target") end
  end

  local chunk = assert(loadfile("Core.lua"))
  chunk("ResourceDing", {})
  local addon = _G.ResourceDing
  frame.fn(nil, "ADDON_LOADED", "ResourceDing")
  return addon, frame
end

-- Classic Era ----------------------------------------------------------------

local addon = stubClient{ classic = true, maxPower = 0, combo = 0 }

assert(not registered.PLAYER_SPECIALIZATION_CHANGED,
  "Classic has no specialisations; registering that event is an error at load")
assert(registered.UNIT_COMBO_POINTS,
  "Classic's combo points change without a UNIT_POWER event, so this one is needed")
assert(registered.UNIT_POWER_FREQUENT and registered.ADDON_LOADED,
  "the events both games share must still be registered")

assert(addon.RESOURCES.ROGUE and addon.RESOURCES.DRUID, "combo points exist in vanilla")
for _, class in ipairs({ "MONK", "PALADIN", "WARLOCK", "MAGE", "EVOKER" }) do
  assert(addon.RESOURCES[class] == nil,
    class .. "'s resource was added after vanilla and must not be offered on Classic")
end

local order = table.concat(addon.SOUND_ORDER, ",")
assert(not order:find("bell"), "a sound this client cannot name must be dropped, got " .. order)
assert(addon.SOUNDS.bell == nil)
assert(#addon.SOUND_ORDER == 6, "the other six are all present on Classic")

-- Combo points live on the target there, so UnitPower reports nothing and
-- GetComboPoints is what answers.
addon = stubClient{ classic = true, maxPower = 0, combo = 5 }
local resource, current, maximum = addon.GetResourceState()
assert(resource and current == 5 and maximum == 5,
  "expected 5/5 from the target, got " .. tostring(current) .. "/" .. tostring(maximum))

-- and it dings on the way to full, once. Starting already full is not a
-- transition and must stay silent, which is why this begins at empty.
addon = stubClient{ classic = true, maxPower = 0, combo = 0 }
played = {}
addon.CheckPower(false)
assert(#played == 0, "empty is not a reason to ding")
comboNow = 5
addon.CheckPower(false)
assert(#played == 1, "should ding on reaching maximum, got " .. #played)
addon.CheckPower(false)
assert(#played == 1, "must not ding again while it stays full")
comboNow = 0
addon.CheckPower(false)
comboNow = 5
addon.CheckPower(false)
assert(#played == 2, "spending and refilling is a fresh transition")

-- Retail ---------------------------------------------------------------------

addon = stubClient{ classic = false, power = 5, maxPower = 5 }
assert(registered.PLAYER_SPECIALIZATION_CHANGED, "Retail still watches spec changes")
for _, class in ipairs({ "ROGUE", "DRUID", "MONK", "PALADIN", "WARLOCK", "MAGE", "EVOKER" }) do
  assert(addon.RESOURCES[class], class .. " must keep its resource on Retail")
end
assert(addon.SOUNDS.bell, "Retail keeps the sound Classic cannot play")

-- UnitPower answers here, so the target is never consulted -- the stub throws
-- if it is.
resource, current, maximum = addon.GetResourceState()
assert(current == 5 and maximum == 5, "Retail should read the player's own power")

print("classic: ok")
