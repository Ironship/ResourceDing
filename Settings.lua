local Addon = ResourceDing

local function checkbox(parent, name, label, y, getter, setter)
  local control = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  control:SetPoint("TOPLEFT", 16, y)
  local text = _G[name .. "Text"]
  if text then text:SetText(label) end
  control:SetChecked(getter())
  control:SetScript("OnClick", function(self) setter(self:GetChecked()) end)
  return control
end

function Addon.CreateSettingsPanel()
  if Addon.settingsPanel then return Addon.settingsPanel end
  local panel = CreateFrame("Frame", "ResourceDingSettingsPanel", UIParent)
  panel.name = "ResourceDing"
  Addon.settingsPanel = panel

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ResourceDing")

  local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  subtitle:SetPoint("TOPLEFT", 16, -44)
  subtitle:SetPoint("TOPRIGHT", -16, -44)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetText("Hear a single cue when your class finisher resource reaches maximum.")

  local resourceText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  resourceText:SetPoint("TOPLEFT", 16, -72)
  resourceText:SetTextColor(0.35, 0.68, 1)
  panel.resourceText = resourceText

  panel.enabled = checkbox(panel, "ResourceDingEnabledCheck", "Enable ResourceDing", -102,
    function() return Addon.db.enabled end,
    function(value) Addon.db.enabled = value; Addon.ResetPowerState() end)

  panel.combatOnly = checkbox(panel, "ResourceDingCombatCheck", "Only play while in combat", -134,
    function() return Addon.db.combatOnly end,
    function(value) Addon.db.combatOnly = value; Addon.ResetPowerState() end)

  local soundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  soundLabel:SetPoint("TOPLEFT", 16, -178)
  soundLabel:SetText("Sound")

  local dropdown = CreateFrame("Frame", "ResourceDingSoundDropdown", panel, "UIDropDownMenuTemplate")
  dropdown:SetPoint("TOPLEFT", 8, -196)
  UIDropDownMenu_SetWidth(dropdown, 220)
  panel.dropdown = dropdown

  local function updateSoundText()
    local sound = Addon.SOUNDS[Addon.db.sound] or Addon.SOUNDS.auction
    UIDropDownMenu_SetText(dropdown, sound.name)
  end

  UIDropDownMenu_Initialize(dropdown, function(_, level)
    for _, key in ipairs(Addon.SOUND_ORDER) do
      local sound = Addon.SOUNDS[key]
      local info = UIDropDownMenu_CreateInfo()
      info.text = sound.name
      info.value = key
      info.checked = Addon.db.sound == key
      info.func = function()
        Addon.db.sound = key
        updateSoundText()
        Addon.PlaySelectedSound()
      end
      UIDropDownMenu_AddButton(info, level or 1)
    end
  end)
  updateSoundText()

  local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  test:SetSize(90, 26)
  test:SetPoint("TOPLEFT", 254, -203)
  test:SetText("Test sound")
  test:SetScript("OnClick", Addon.PlaySelectedSound)

  local supported = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  supported:SetPoint("TOPLEFT", 16, -252)
  supported:SetPoint("TOPRIGHT", -16, -252)
  supported:SetJustifyH("LEFT")
  supported:SetWordWrap(true)
  supported:SetText("Supported: Rogue and Feral Druid Combo Points, Monk Chi, Paladin Holy Power, Warlock Soul Shards, Arcane Mage Charges, and Evoker Essence. Unsupported specs stay silent.")

  panel.refresh = function()
    local resource, current, maximum = Addon.GetResourceState()
    if resource and maximum > 0 then
      resourceText:SetText(string.format("Detected: %s (%d / %d)", resource.name, current, maximum))
    elseif resource then
      resourceText:SetText("Detected: " .. resource.name .. " (inactive for this spec/form)")
    else
      resourceText:SetText("No supported resource for this class")
    end
    panel.enabled:SetChecked(Addon.db.enabled)
    panel.combatOnly:SetChecked(Addon.db.combatOnly)
    UIDropDownMenu_Initialize(dropdown, function(_, level)
      for _, key in ipairs(Addon.SOUND_ORDER) do
        local sound = Addon.SOUNDS[key]
        local info = UIDropDownMenu_CreateInfo()
        info.text = sound.name
        info.value = key
        info.checked = Addon.db.sound == key
        info.func = function() Addon.db.sound = key; updateSoundText(); Addon.PlaySelectedSound() end
        UIDropDownMenu_AddButton(info, level or 1)
      end
    end)
    updateSoundText()
  end

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    category.ID = panel.name
    Settings.RegisterAddOnCategory(category)
    Addon.settingsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  return panel
end

function Addon.OpenSettings()
  if not Addon.settingsPanel then Addon.CreateSettingsPanel() end
  Addon.settingsPanel.refresh()
  if Settings and Settings.OpenToCategory and Addon.settingsCategory then
    local id = Addon.settingsCategory.GetID and Addon.settingsCategory:GetID() or Addon.settingsCategory.ID
    if id then Settings.OpenToCategory(id) end
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(Addon.settingsPanel)
    InterfaceOptionsFrame_OpenToCategory(Addon.settingsPanel)
  end
end
