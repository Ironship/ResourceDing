local addonName, Addon = ...
_G.ResourceDing = Addon

local function powerType(name, fallback)
  return Enum and Enum.PowerType and Enum.PowerType[name] or fallback
end

Addon.RESOURCES = {
  ROGUE = { name = "Combo Points", power = powerType("ComboPoints", 4) },
  DRUID = { name = "Combo Points", power = powerType("ComboPoints", 4) },
  MONK = { name = "Chi", power = powerType("Chi", 12) },
  PALADIN = { name = "Holy Power", power = powerType("HolyPower", 9) },
  WARLOCK = { name = "Soul Shards", power = powerType("SoulShards", 7) },
  MAGE = { name = "Arcane Charges", power = powerType("ArcaneCharges", 16) },
  EVOKER = { name = "Essence", power = powerType("Essence", 19) },
}

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

local defaults = {
  enabled = true,
  combatOnly = true,
  sound = "auction",
}

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
  return resource, UnitPower("player", resource.power) or 0, UnitPowerMax("player", resource.power) or 0
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
    end
  end
  Addon.wasFull = isFull
end

function Addon.ResetPowerState()
  Addon.CheckPower(true)
  if Addon.settingsPanel and Addon.settingsPanel.refresh then Addon.settingsPanel.refresh() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
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
    print("|cff66ccffResourceDing:|r enabled")
  elseif command == "off" then
    Addon.db.enabled = false
    print("|cff66ccffResourceDing:|r disabled")
  elseif Addon.OpenSettings then
    Addon.OpenSettings()
  end
end
