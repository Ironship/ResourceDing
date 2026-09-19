-- Run from the addon root:  lua tests/classic.test.lua
--
-- Written without a Classic client to try it on, so this stands in for one. It
-- loads Core.lua against a fake Retail API, a fake Classic Era one, and a fake
-- WoW Forever one -- Classic Era's API on a client that calls itself Retail --
-- and checks the places the games disagree.
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
                          "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "ResourceDingDB",
                          "C_AddOns", "GetAddOnMetadata", "issecretvalue",
                          "hooksecurefunc", "ComboFrame", "ComboFrame_Update",
                          "GetBuildInfo" }) do
    _G[name] = nil
  end
  for i = 1, 6 do _G["ComboPoint" .. i] = nil end

  -- A 12.x client's secret value: it answers issecretvalue, and any comparison
  -- on it is an error, which is how the real one took the addon down.
  local SECRET = {
    __lt = function() error("attempt to compare a secret number value") end,
    __le = function() error("attempt to compare a secret number value") end,
  }
  secret = function() return setmetatable({}, SECRET) end
  if opts.forever then
    issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == SECRET end
  end

  -- Forever: the API is Classic Era's, the project id is Retail's, and the
  -- manifest the client loaded is the Camelot one. Everything below that
  -- models the game's API follows classicApi; the id alone follows opts.classic.
  local classicApi = opts.classic or opts.forever
  WOW_PROJECT_MAINLINE = 1
  WOW_PROJECT_ID = opts.classic and 2 or 1
  -- The manifest the client loaded. Forever loads the Mainline one, which
  -- lists both games, so it is the version that tells Forever apart.
  C_AddOns = { GetAddOnMetadata = function(_, field)
    if field ~= "Interface" then return nil end
    if opts.classic then return "11509" end
    return "120100, 16001"
  end }
  GetBuildInfo = function()
    if opts.forever then return "1.60.1", "69893", "2026-09-01", nil end
    if opts.classic then return "1.15.9", "62222", "2026-09-01", 11509 end
    return "12.1.0", "69814", "2026-09-01", 120100
  end

  Enum = { PowerType = { ComboPoints = 4, Chi = 12, HolyPower = 9,
                         SoulShards = 7, ArcaneCharges = 16, Essence = 19 } }

  SOUNDKIT = { AUCTION_WINDOW_OPEN = 5274, READY_CHECK = 8960, UI_QUEST_COMPLETE = 878,
               LEVEL_UP = 888, LOOT_MONEY_COINS = 120, RAID_WARNING = 8959 }
  -- A Legion sound. The Classic client has never heard of it.
  if not classicApi then SOUNDKIT.UI_ORDERHALL_TALENT_READY_TOAST = 73743 end

  local known = {
    ADDON_LOADED = true, PLAYER_ENTERING_WORLD = true, UPDATE_SHAPESHIFT_FORM = true,
    PLAYER_TARGET_CHANGED = true, UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true,
    UNIT_MAXPOWER = true, PLAYER_REGEN_DISABLED = true,
  }
  if classicApi then
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
  if classicApi then
    MAX_COMBO_POINTS = 5
    comboNow = opts.combo or 0
    GetComboPoints = function() return comboNow end
  else
    -- Retail must never fall back to this; if it does, say so loudly.
    GetComboPoints = function() error("Retail must not read combo points off the target") end
  end

  -- The game's own combo display, on the clients that draw it the classic
  -- way, modelled on Blizzard's ComboFrame_Update: every point frame is shown
  -- once the first point is earned, an earned point's Highlight is at alpha 1
  -- and an unearned one's at 0, and the frame hides at zero. comboLit is how
  -- many are lit. Timers run at once, so the delayed look happens in-line.
  hooks, scriptHooks = {}, {}
  hooksecurefunc = function(name, fn) hooks[name] = fn end
  -- Blizzard's layout for a maximum of five: ComboPoint1 stays hidden,
  -- ComboPoint2 to ComboPoint6 carry the points, the sixth shown only when
  -- earned. Measured on the Forever client, 2026-09-19.
  if opts.classic or opts.forever then
    ComboFrame_Update = function() end
    ComboPointShineFadeIn = function() end
    comboLit = 0
    ComboFrame = {
      IsShown = function() return comboLit > 0 end,
      HookScript = function(_, handler, fn) scriptHooks[handler] = fn end,
    }
    ComboPoint1 = { IsShown = function() return false end, Highlight = { GetAlpha = function() return 0 end } }
    for i = 2, 6 do
      local slot = i - 1
      _G["ComboPoint" .. i] = {
        IsShown = function() return comboLit > 0 and (slot < 5 or comboLit >= 5) end,
        Highlight = { GetAlpha = function() return comboLit >= slot and 1 or 0 end },
      }
    end
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

-- WoW Forever ----------------------------------------------------------------
-- The project id says Retail. The manifest says 16001. The manifest wins, or
-- the addon registers an event this game does not have and dies at load.

addon = stubClient{ forever = true, maxPower = 0, combo = 0 }
assert(addon.IsClassic() == true, "Forever must count as Classic, whatever WOW_PROJECT_ID says")
assert(not registered.PLAYER_SPECIALIZATION_CHANGED,
  "Forever has no specialisations; registering that event is an error at load")
assert(registered.UNIT_COMBO_POINTS, "Forever's combo points change like Classic's")
for _, class in ipairs({ "MONK", "PALADIN", "WARLOCK", "MAGE", "EVOKER" }) do
  assert(addon.RESOURCES[class] == nil, class .. " does not exist on Forever")
end
assert(addon.SOUNDS.bell == nil, "and the Legion sound is not offered there")
addon = stubClient{ forever = true, maxPower = 0, combo = 5 }
local fResource, fCurrent, fMaximum = addon.GetResourceState()
assert(fResource and fCurrent == 5 and fMaximum == 5,
  "Forever reads combo points off the target, got " .. tostring(fCurrent) .. "/" .. tostring(fMaximum))

-- What the Forever client actually does (2026-09-19): UnitPowerMax says five,
-- UnitPower is secret in a fight, and only the display tells. Five lit is a
-- ding, whatever path the number failed on.
addon = stubClient{ forever = true, maxPower = 5, combo = 0 }
UnitPower = function() return secret() end
played = {}
comboLit = 5
scriptHooks.OnEvent()
assert(#played == 1, "a secret UnitPower with five lit highlights is a full bar, got " .. #played)
local _, pCurrent, pMaximum = addon.GetResourceState()
assert(pCurrent == 5 and pMaximum == 5, "read from the display, got " .. tostring(pCurrent) .. "/" .. tostring(pMaximum))
comboLit = 4
local _, pFour = addon.GetResourceState()
assert(pFour == 4, "four lit of ComboPoint2..6 is four, got " .. tostring(pFour))
-- A frame the client hid is not lit whatever alpha it was left with: the
-- sixth point frame keeps its highlight when the count drops below five, and
-- is simply hidden.
ComboPoint6.IsShown = function() return false end
ComboPoint6.Highlight.GetAlpha = function() return 1 end
local _, pHidden = addon.GetResourceState()
assert(pHidden == 4, "a hidden frame with its highlight left up is not a point, got " .. tostring(pHidden))

-- In a fight the Forever client keeps that count secret. The addon must
-- neither raise on it nor decide anything from it; when the plain number is
-- back, the ding is the one it always was.
addon = stubClient{ forever = true, maxPower = 0, combo = 0 }
played = {}
addon.CheckPower(false)
comboNow = secret()
local okSecret, errSecret = pcall(addon.CheckPower, false)
assert(okSecret, "a secret count must not raise: " .. tostring(errSecret))
assert(#played == 0, "and must not ding")
local _, sCurrent = addon.GetResourceState()
assert(sCurrent == 0, "with the number secret the display answers, and nothing lit is 0, got " .. tostring(sCurrent))
comboNow = 5
addon.CheckPower(false)
assert(#played == 1, "the count coming back plain at full is the ding it always was, got " .. #played)

-- What Forever does give away is its own display: one frame per earned
-- point, drawn by code allowed to read the count. With the number secret for
-- the whole fight, the addon counts the frames -- after Blizzard has redrawn
-- them, through the post-hook on ComboFrame_Update.
addon = stubClient{ forever = true, maxPower = 0, combo = 0 }
assert(type(scriptHooks.OnEvent) == "function", "the display frame's own events are hooked")
assert(type(hooks.ComboFrame_Update) == "function", "and its update function, where the client has it")
assert(type(hooks.ComboPointShineFadeIn) == "function", "and the end of a highlight's fade")
played = {}
comboNow = secret()
comboLit = 0
scriptHooks.OnEvent()
assert(#played == 0, "nothing lit is not a reason to ding")
comboLit = 5
scriptHooks.OnEvent()
assert(#played == 1, "five lit highlights is a full bar, got " .. #played)
hooks.ComboPointShineFadeIn()
hooks.ComboFrame_Update()
assert(#played == 1, "still full, still one ding")
comboLit = 0
scriptHooks.OnEvent()
comboLit = 5
hooks.ComboPointShineFadeIn()
assert(#played == 2, "spent and rebuilt is a fresh transition, got " .. #played)
-- Every point frame is shown once one point is earned; only the highlights
-- say how many. Four lit of five shown must not read as full.
comboLit = 0
scriptHooks.OnEvent()
comboLit = 4
played = {}
scriptHooks.OnEvent()
assert(#played == 0, "four lit highlights among five shown frames is not full")
local _, dFour = addon.GetResourceState()
assert(dFour == 4, "four lit reads as four, got " .. tostring(dFour))
comboLit = 5
local _, dCurrent, dMaximum = addon.GetResourceState()
assert(dCurrent == 5 and dMaximum == 5,
  "the state reads the display when the number is secret, got " .. tostring(dCurrent) .. "/" .. tostring(dMaximum))
comboLit = 3
local _, dThree = addon.GetResourceState()
assert(dThree == 3, "three lit frames read as three, got " .. tostring(dThree))

-- A display the client keeps secret as well reads as unknown -- and never
-- raises.
ComboPoint4.Highlight.GetAlpha = function() return secret() end
comboLit = 5
played = {}
local okDisplay, errDisplay = pcall(addon.CheckPower, false)
assert(okDisplay, "a secret frame state must not raise: " .. tostring(errDisplay))
assert(#played == 0, "and decides nothing")
local _, dSecret = addon.GetResourceState()
assert(dSecret == nil, "unknown, not a number, got " .. tostring(dSecret))

-- Classic Era proper hands the number over plainly, so the display is never
-- consulted there: a frame count that disagrees with the number changes nothing.
addon = stubClient{ classic = true, maxPower = 0, combo = 2 }
comboLit = 5
local _, cCurrent = addon.GetResourceState()
assert(cCurrent == 2, "Classic Era reads the number, not the display, got " .. tostring(cCurrent))

-- Retail ---------------------------------------------------------------------

addon = stubClient{ classic = false, power = 5, maxPower = 5 }
assert(addon.IsClassic() == false, "a Retail manifest (120100) is not Forever")
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
