local addonName, Addon = ...
_G.ResourceDing = Addon

local function powerType(name, fallback)
  return Enum and Enum.PowerType and Enum.PowerType[name] or fallback
end

-- Retail, Classic Era, Season of Discovery and WoW Forever run the same addon.
-- What differs is which of these resources the game actually has.
--
-- Forever is the awkward one. It is a Classic Era game -- vanilla content, the
-- Classic Era API -- built on the Retail client, and that client answers
-- WOW_PROJECT_ID the way Retail does. Asked the usual way, the addon would
-- think it was on Retail, offer Chi and Holy Power to classes that do not
-- exist there, and register a specialisation event the game may not have,
-- which is an error at load.
--
-- The one answer that client gives that is not Retail's is its version: Retail
-- is 12.x, Classic Era 1.15.x, Forever 1.60.x. Not the manifest: measured on
-- 2026-09-19 with /rding probe, the Forever client loads the _Mainline
-- manifest, not a _Camelot one, so the manifest says what Retail's says. That
-- is why ResourceDing_Mainline.toc lists 16001 beside 120100 -- the same
-- convention AtlasLoot ships for that game -- and why the flavour is read
-- from GetBuildInfo's version string, the first value it returns.
local function clientIsForever()
  if type(GetBuildInfo) ~= "function" then return false end
  local ok, version = pcall(GetBuildInfo)
  if not ok or type(version) ~= "string" then return false end
  local major, minor = version:match("^(%d+)%.(%d+)")
  return tonumber(major) == 1 and (tonumber(minor) or 0) >= 60
end

local function isClassic()
  if clientIsForever() then return true end
  if type(WOW_PROJECT_ID) ~= "number" or type(WOW_PROJECT_MAINLINE) ~= "number" then
    return false
  end
  return WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
end
Addon.IsClassic = isClassic

Addon.RESOURCES = {
  ROGUE = { name = "Combo Points", power = powerType("ComboPoints", 4), comboPoints = true },
  DRUID = { name = "Combo Points", power = powerType("ComboPoints", 4), comboPoints = true },
  MONK = { name = "Chi", power = powerType("Chi", 12) },
  PALADIN = { name = "Holy Power", power = powerType("HolyPower", 9) },
  WARLOCK = { name = "Soul Shards", power = powerType("SoulShards", 7) },
  MAGE = { name = "Arcane Charges", power = powerType("ArcaneCharges", 16) },
  EVOKER = { name = "Essence", power = powerType("Essence", 19) },
}

-- Vanilla has combo points and nothing else. Chi, Holy Power, Arcane Charges
-- and the Soul Shard bar were all added by later expansions, and Monk and
-- Evoker do not exist there at all. Leaving them listed would have the settings
-- panel announce a resource the player's class cannot have in that game.
if isClassic() then
  for class in pairs(Addon.RESOURCES) do
    if class ~= "ROGUE" and class ~= "DRUID" then Addon.RESOURCES[class] = nil end
  end
end

Addon.SOUNDS = {
  auction = { name = "Auction House", id = SOUNDKIT and SOUNDKIT.AUCTION_WINDOW_OPEN or 5274 },
  ready = { name = "Ready Check", id = SOUNDKIT and SOUNDKIT.READY_CHECK or 8960 },
  quest = { name = "Quest Complete", id = SOUNDKIT and SOUNDKIT.UI_QUEST_COMPLETE or 878 },
  level = { name = "Level Up", id = SOUNDKIT and SOUNDKIT.LEVEL_UP or 888 },
  bell = { name = "UI Bell", id = SOUNDKIT and SOUNDKIT.UI_ORDERHALL_TALENT_READY_TOAST or 73743 },
  coins = { name = "Loot Coins", id = SOUNDKIT and SOUNDKIT.LOOT_MONEY_COINS or 120 },
  warning = { name = "Raid Warning", id = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959 },
}
Addon.SOUND_ORDER = { "auction", "ready", "quest", "level", "bell", "coins", "warning" }

-- A sound added in a later expansion does not exist on the Classic client, and
-- PlaySound on an id it does not know fails quietly. Offering it would give the
-- player a choice that appears to do nothing, so a sound this client cannot
-- name is dropped from the list instead of shipped broken. The numeric
-- fallbacks above are only for a client with no SOUNDKIT table at all.
if SOUNDKIT then
  local KEYS = {
    auction = "AUCTION_WINDOW_OPEN", ready = "READY_CHECK", quest = "UI_QUEST_COMPLETE",
    level = "LEVEL_UP", bell = "UI_ORDERHALL_TALENT_READY_TOAST",
    coins = "LOOT_MONEY_COINS", warning = "RAID_WARNING",
  }
  local kept = {}
  for _, key in ipairs(Addon.SOUND_ORDER) do
    if SOUNDKIT[KEYS[key]] then kept[#kept + 1] = key else Addon.SOUNDS[key] = nil end
  end
  if #kept > 0 then Addon.SOUND_ORDER = kept end
end

local defaults = {
  enabled = true,
  combatOnly = true,
  sound = "auction",
  dots = true,     -- combo points as dots under the target's nameplate (Dots.lua)
  dotSize = 14,
  dotOffset = 2,   -- below the plate's health bar
}
Addon.defaults = defaults

local function initializeDatabase()
  if type(ResourceDingDB) ~= "table" then ResourceDingDB = {} end
  for key, value in pairs(defaults) do
    if ResourceDingDB[key] == nil then ResourceDingDB[key] = value end
  end
  if not Addon.SOUNDS[ResourceDingDB.sound] then ResourceDingDB.sound = defaults.sound end
  Addon.db = ResourceDingDB
end

function Addon.GetResource()
  local _, class = UnitClass("player")
  return class and Addon.RESOURCES[class] or nil
end

-- A number the client will let this addon use, 0 for no answer, or nil for a
-- number it will not.
--
-- Clients from 12.0 on hand insecure code "secret" values for some combat
-- data: a number a secure bar can show, but that a comparison or a sum in an
-- addon raises on. WoW Forever is such a client, and its combo points live on
-- the target, so GetComboPoints answers with one during a fight -- and a
-- comparison on it inside an event handler took the whole addon down until
-- the next reload (Core.lua:150, 2026-09-19). Asked before every use, so a
-- secret reads as "unknown": not a full bar, and not an empty one either.
local function known(value)
  if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
  return type(value) == "number" and value or 0
end
Addon.KnownNumber = known

-- What the game's own combo point display is showing, for the client that
-- keeps the number itself secret.
--
-- Forever draws combo points with the classic ComboFrame -- ComboPoint1 to
-- ComboPoint5 -- by secure code that is allowed to read the count (/fstack on
-- the Forever client, 2026-09-19: ComboFrame, ComboPoint5.Highlight,
-- ComboFrame.xml:62). That code cannot keep its display secret: a widget's
-- alpha is plain state. What it does is worth being exact about, from
-- Blizzard's ComboFrame_Update: once one point is earned every point frame is
-- shown, and an earned point differs from an unearned one only by its
-- Highlight -- faded in over 0.4 s for a new point, set to alpha 0 when the
-- point is gone; the whole frame hides at zero. So a point counts as lit when
-- its Highlight is up, and the frame's own visibility only says "none".
--
-- Read as defensively as the number: should a client hand back a secret here
-- too, the answer is nil -- unknown -- as before, never an error.
local function plainValue(ok, value)
  if not ok then return nil end
  if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
  return value
end

local function displayedComboPoints()
  local frame = _G.ComboFrame
  if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then return nil end
  local shown = plainValue(pcall(frame.IsShown, frame))
  if shown == nil then return nil end
  if not shown then return 0 end
  -- Every point frame there is, not the first five: with a maximum of five
  -- Blizzard draws ComboPoint2 to ComboPoint6 and leaves ComboPoint1 hidden
  -- (startComboPointIndex is 2 unless the maximum is 6 or 9), which is how a
  -- count of the first five read four at a full bar on 2026-09-19. A hidden
  -- frame is not lit whatever its alpha says.
  local count = 0
  for index = 1, 12 do
    local point = _G["ComboPoint" .. index]
    local highlight = type(point) == "table" and point.Highlight
    if type(highlight) ~= "table" or type(highlight.GetAlpha) ~= "function" then break end
    local visible = plainValue(pcall(point.IsShown, point))
    local alpha = plainValue(pcall(highlight.GetAlpha, highlight))
    if visible == nil or type(alpha) ~= "number" then return nil end
    if visible and alpha > 0.5 then count = count + 1 end
  end
  return count
end
Addon.DisplayedComboPoints = displayedComboPoints

function Addon.GetResourceState()
  local resource = Addon.GetResource()
  if not resource then return nil, 0, 0 end
  local current = known(UnitPower("player", resource.power))
  local maximum = known(UnitPowerMax("player", resource.power)) or 0
  -- On the Classic client a rogue's or a cat druid's combo points belong to the
  -- target rather than to the player, and UnitPower reports none of them.
  -- GetComboPoints is the call that answers there. Retail is left alone: this
  -- is only reached when UnitPower has already said there is no such bar.
  -- Only on the client where combo points belong to the target. A Retail druid
  -- out of cat form reports a maximum of zero too, and this branch then read
  -- combo points off the target and reported a bar that spec does not have.
  if maximum <= 0 and resource.comboPoints and isClassic()
      and type(GetComboPoints) == "function" then
    -- The target's count, when the client gives it plainly. Forever keeps it
    -- secret in combat, and then the answer is nil: unknown, not zero.
    current = known(GetComboPoints("player", "target"))
    maximum = MAX_COMBO_POINTS or 5
  end
  -- Whichever call answered, a secret is a secret: on Forever UnitPower does
  -- report a maximum of five and then withholds the count in combat. Where
  -- the client draws the classic display, that says what the number would.
  if current == nil and resource.comboPoints then
    current = displayedComboPoints()
  end
  return resource, current, maximum
end

function Addon.PlaySelectedSound()
  -- Falls through to whatever sound this client does have. The filter above
  -- drops any SOUNDKIT entry the client is missing, and the default is not
  -- exempt from that -- without a floor, a client without the auction sound
  -- would error on every full bar instead of playing something else.
  local choice = Addon.SOUNDS[Addon.db and Addon.db.sound or defaults.sound]
    or Addon.SOUNDS.auction
    or select(2, next(Addon.SOUNDS))
  if not choice or not choice.id then return false end
  return PlaySound(choice.id, "Master", true)
end

function Addon.CheckPower(silent)
  local resource, current, maximum = Addon.GetResourceState()
  if not resource or maximum <= 0 then
    Addon.wasFull = false
    return
  end
  -- Unknown this time: the client kept the number to itself. That says
  -- nothing about full or not, so the latch is left exactly as it was.
  if current == nil then return end

  local isFull = current >= maximum
  if not silent and isFull and not Addon.wasFull and Addon.db.enabled then
    if not Addon.db.combatOnly or UnitAffectingCombat("player") then
      Addon.PlaySelectedSound()
    else
      -- Full, but out of combat and the player asked for combat only. The sound
      -- is skipped -- and the state is deliberately left unlatched, so the ding
      -- still happens the moment combat starts.
      --
      -- Latching here is what made a rogue's opener silent. Ambush and Cheap
      -- Shot award their combo points in the same instant the fight begins, and
      -- UnitAffectingCombat is routinely still false when the event arrives. The
      -- addon saw a full bar, said nothing because combat had not registered
      -- yet, and recorded the bar as already announced. The fight then started
      -- with the points already there and no further rise to announce.
      return
    end
  end
  Addon.wasFull = isFull
end

function Addon.RestoreDefaults()
  for key, value in pairs(defaults) do Addon.db[key] = value end
  Addon.ResetPowerState()
end

function Addon.ResetPowerState()
  Addon.CheckPower(true)
  if Addon.RefreshDots then Addon.RefreshDots() end
  if Addon.settingsPanel and Addon.settingsPanel.refresh then Addon.settingsPanel.refresh() end
end

local events = CreateFrame("Frame")

-- Registering an event the client does not have raises an error, and this runs
-- at load, before the addon has done anything -- so one absent name would take
-- the whole thing down rather than cost it a feature. PLAYER_SPECIALIZATION_CHANGED
-- is exactly that on Classic Era, which has no specialisations at all.
local function listenFor(event, unit)
  local method = unit and events.RegisterUnitEvent or events.RegisterEvent
  return (pcall(method, events, event, unit))
end

-- When to look at the display.
--
-- The events this addon listens to are not promised on the client that needs
-- the display: combo points on the target raise no UNIT_POWER event for the
-- player there. So the display's own redraws are the trigger. ComboFrame
-- handles PLAYER_TARGET_CHANGED and the power events itself, and a post-hook
-- on its OnEvent runs after that redraw; a newly earned point's Highlight is
-- still at alpha 0 then, fading in over 0.4 s, so the same look is taken
-- again half a second later, when it is up. ComboPointShineFadeIn is what
-- Blizzard calls when that fade finishes, and where the client has it as a
-- global, it is the exact moment. All post-hooks: none of this taints the
-- frame, and a client without the frame -- Classic Era draws its own -- has
-- no hooks and reads the number as it always did.
local HIGHLIGHT_SETTLED = 0.5

local function lookAtDisplay()
  Addon.looks = (Addon.looks or 0) + 1
  if Addon.db then Addon.CheckPower(false) end
  -- the display has the count plainly now: the dots show it too
  if Addon.RefreshDots then Addon.RefreshDots() end
end

local function lookAgainLater()
  if C_Timer and C_Timer.After then C_Timer.After(HIGHLIGHT_SETTLED, lookAtDisplay) end
end

Addon.hooks = {}
if type(ComboFrame) == "table" and type(ComboFrame.HookScript) == "function" then
  Addon.hooks.frame = (pcall(ComboFrame.HookScript, ComboFrame, "OnEvent", function()
    lookAtDisplay()
    lookAgainLater()
  end))
end
if type(hooksecurefunc) == "function" then
  if type(ComboFrame_Update) == "function" then
    hooksecurefunc("ComboFrame_Update", function()
      lookAtDisplay()
      lookAgainLater()
    end)
    Addon.hooks.update = true
  end
  if type(ComboPointShineFadeIn) == "function" then
    hooksecurefunc("ComboPointShineFadeIn", lookAtDisplay)
    Addon.hooks.shine = true
  end
end
Addon.LookAtDisplay = lookAtDisplay

listenFor("ADDON_LOADED")
listenFor("PLAYER_ENTERING_WORLD")
listenFor("PLAYER_SPECIALIZATION_CHANGED")
listenFor("UPDATE_SHAPESHIFT_FORM")
listenFor("PLAYER_TARGET_CHANGED")
-- Entering combat is itself worth a check: the resource may have filled a
-- moment earlier, while the sound was still being held back.
listenFor("PLAYER_REGEN_DISABLED")
listenFor("UNIT_POWER_UPDATE", "player")
listenFor("UNIT_POWER_FREQUENT", "player")
listenFor("UNIT_MAXPOWER", "player")
-- Classic's combo points change without any UNIT_POWER event, because they are
-- not the player's power there. This is what fires instead.
listenFor("UNIT_COMBO_POINTS", "player")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= addonName then return end
    initializeDatabase()
    if Addon.CreateSettingsPanel then Addon.CreateSettingsPanel() end
    Addon.ResetPowerState()
    if Addon.StartDots then Addon.StartDots() end
  elseif not Addon.db then
    return
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UNIT_MAXPOWER" then
    C_Timer.After(0, Addon.ResetPowerState)
  else
    Addon.CheckPower(false)
  end
end)

SLASH_RESOURCEDING1 = "/rding"
SLASH_RESOURCEDING2 = "/resourceding"
SlashCmdList.RESOURCEDING = function(message)
  local command = strlower(strtrim(tostring(message or "")))
  if command == "test" then
    Addon.PlaySelectedSound()
  elseif command == "probe" then
    -- Everything the decision rests on, as the game hands it over right now,
    -- for a client that keeps some of it secret. Typed in a fight, at the
    -- count that should have dinged.
    local function show(v)
      if type(issecretvalue) == "function" and issecretvalue(v) then return "<secret>" end
      return tostring(v)
    end
    local function call(object, method)
      if type(object) ~= "table" or type(object[method]) ~= "function" then return "-" end
      local ok, v = pcall(object[method], object)
      return ok and show(v) or ("error: " .. tostring(v))
    end
    local resource = Addon.GetResource()
    print("|cff66ccffResourceDing probe:|r resource " .. tostring(resource and resource.name)
      .. "  classic=" .. tostring(isClassic()) .. "  combat=" .. show(UnitAffectingCombat("player")))
    if resource then
      print("  UnitPower " .. show(UnitPower("player", resource.power))
        .. "  UnitPowerMax " .. show(UnitPowerMax("player", resource.power)))
    end
    if type(GetComboPoints) == "function" then
      print("  GetComboPoints " .. show(GetComboPoints("player", "target"))
        .. "  MAX_COMBO_POINTS " .. tostring(MAX_COMBO_POINTS))
    end
    print("  ComboFrame " .. type(_G.ComboFrame) .. " shown=" .. call(_G.ComboFrame, "IsShown")
      .. "  ComboFrame_Update=" .. type(ComboFrame_Update) .. "  ShineFadeIn=" .. type(ComboPointShineFadeIn))
    for i = 1, 5 do
      local point = _G["ComboPoint" .. i]
      print(string.format("  ComboPoint%d shown=%s  Highlight alpha=%s", i, call(point, "IsShown"),
        call(type(point) == "table" and point.Highlight, "GetAlpha")))
    end
    local _, current, maximum = Addon.GetResourceState()
    print("  displayed=" .. tostring(displayedComboPoints()) .. "  state " .. tostring(current) .. "/" .. tostring(maximum)
      .. "  wasFull=" .. tostring(Addon.wasFull) .. "  looks=" .. tostring(Addon.looks or 0)
      .. "  hooks frame=" .. tostring(Addon.hooks and Addon.hooks.frame) .. " update=" .. tostring(Addon.hooks and Addon.hooks.update)
      .. " shine=" .. tostring(Addon.hooks and Addon.hooks.shine))
  elseif command == "on" then
    Addon.db.enabled = true
    Addon.ResetPowerState()
    print("|cff66ccffResourceDing:|r enabled")
  elseif command == "off" then
    Addon.db.enabled = false
    Addon.ResetPowerState()
    print("|cff66ccffResourceDing:|r disabled")
  elseif Addon.OpenSettings then
    Addon.OpenSettings()
  end
end
