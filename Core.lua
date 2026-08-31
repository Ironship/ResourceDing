local addonName, Addon = ...
_G.ResourceDing = Addon

local function powerType(name, fallback)
  return Enum and Enum.PowerType and Enum.PowerType[name] or fallback
end

-- Retail, Classic Era and Season of Discovery run the same addon. What differs
-- is which of these resources the game actually has.
local function isClassic()
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

function Addon.GetResourceState()
  local resource = Addon.GetResource()
  if not resource then return nil, 0, 0 end
  local current = UnitPower("player", resource.power) or 0
  local maximum = UnitPowerMax("player", resource.power) or 0
  -- On the Classic client a rogue's or a cat druid's combo points belong to the
  -- target rather than to the player, and UnitPower reports none of them.
  -- GetComboPoints is the call that answers there. Retail is left alone: this
  -- is only reached when UnitPower has already said there is no such bar.
  if maximum <= 0 and resource.comboPoints and type(GetComboPoints) == "function" then
    current = GetComboPoints("player", "target") or 0
    maximum = MAX_COMBO_POINTS or 5
  end
  return resource, current, maximum
end

function Addon.PlaySelectedSound()
  local choice = Addon.SOUNDS[Addon.db and Addon.db.sound or defaults.sound] or Addon.SOUNDS.auction
  return PlaySound(choice.id, "Master", true)
end

function Addon.CheckPower(silent)
  local resource, current, maximum = Addon.GetResourceState()
  if not resource or maximum <= 0 then
    Addon.wasFull = false
    return
  end

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
