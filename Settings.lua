local Addon = ResourceDing

local function checkbox(parent, name, label, y, getter, setter)
  local control = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  control:SetPoint("TOPLEFT", 16, y)
  local text = control.Text or control.text or _G[name .. "Text"]
  if text then text:SetText(label) end
  control:SetChecked(getter())
  control:SetScript("OnClick", function(self) setter(self:GetChecked()) end)
  return control
end

-- A slider with its label above and its value to the right, built from a plain Slider so it does
-- not depend on a template every client has.
local function slider(parent, label, y, min, max, getter, setter)
  local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOPLEFT", 16, y)
  text:SetText(label)
  local bar = CreateFrame("Slider", nil, parent)
  bar:SetOrientation("HORIZONTAL")
  bar:SetSize(200, 16)
  bar:SetPoint("TOPLEFT", 18, y - 20)
  bar:SetMinMaxValues(min, max)
  bar:SetValueStep(1)
  if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
  bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.2, 0.2, 0.22, 1)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(6)
  local value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  value:SetPoint("LEFT", bar, "RIGHT", 10, 0)
  bar:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v + 0.5)
    value:SetText(tostring(v))
    if bar.refreshing then return end
    setter(v)
  end)
  bar.Refresh = function()
    bar.refreshing = true
    bar:SetValue(getter())
    value:SetText(tostring(getter()))
    bar.refreshing = false
  end
  return bar
end

local function soundEntries()
  local entries = {}
  for _, key in ipairs(Addon.SOUND_ORDER) do
    entries[#entries + 1] = { key = key, name = Addon.SOUNDS[key].name }
  end
  return entries
end

local function selectSound(key)
  Addon.db.sound = key
  Addon.PlaySelectedSound()
end

local function createDropdown(parent)
  local modern = select(2, pcall(CreateFrame, "DropdownButton", "ResourceDingSoundDropdown", parent,
    "WowStyle1DropdownTemplate"))
  if type(modern) == "table" and modern.SetupMenu then
    modern:SetWidth(230)
    modern:SetupMenu(function(_, rootDescription)
      for _, entry in ipairs(soundEntries()) do
        rootDescription:CreateRadio(entry.name,
          function() return Addon.db.sound == entry.key end,
          function() selectSound(entry.key) end)
      end
    end)
    return modern, function()
      local sound = Addon.SOUNDS[Addon.db.sound] or Addon.SOUNDS.auction
      if modern.SetText then modern:SetText(sound.name) end
      if modern.GenerateMenu then modern:GenerateMenu() end
    end
  end

  local legacy = CreateFrame("Frame", "ResourceDingSoundDropdownLegacy", parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(legacy, 220)
  UIDropDownMenu_Initialize(legacy, function(_, level)
    for _, entry in ipairs(soundEntries()) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = entry.name
      info.value = entry.key
      info.checked = Addon.db.sound == entry.key
      info.func = function()
        selectSound(entry.key)
        UIDropDownMenu_SetText(legacy, Addon.SOUNDS[entry.key].name)
      end
      UIDropDownMenu_AddButton(info, level or 1)
    end
  end)
  return legacy, function()
    local sound = Addon.SOUNDS[Addon.db.sound] or Addon.SOUNDS.auction
    UIDropDownMenu_SetText(legacy, sound.name)
  end
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

  local dropdown, updateSoundText = createDropdown(panel)
  dropdown:SetPoint("TOPLEFT", 8, -196)
  panel.dropdown = dropdown
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
  -- Built from the table the addon actually uses, which Core prunes on Classic
  -- to the two classes that game has. Spelling the full Retail list out here
  -- defeated that pruning: Classic players were told about Chi, Holy Power,
  -- Soul Shards, Arcane Charges and Essence, none of which exist for them.
  local names, seen = {}, {}
  for _, resource in pairs(Addon.RESOURCES) do
    if not seen[resource.name] then
      seen[resource.name] = true
      names[#names + 1] = resource.name
    end
  end
  table.sort(names)
  supported:SetText("Supported: " .. table.concat(names, ", ")
    .. ". Classes without one of these stay silent.")

  -- The dots under the target's nameplate (Dots.lua).
  panel.dots = checkbox(panel, "ResourceDingDotsCheck", "Show the points as dots under the target's nameplate", -290,
    function() return Addon.db.dots end,
    function(value) Addon.db.dots = value; if Addon.RefreshDots then Addon.RefreshDots() end end)
  panel.dotSize = slider(panel, "Dot size", -326, 8, 24,
    function() return Addon.db.dotSize end,
    function(value) Addon.db.dotSize = value; if Addon.RefreshDots then Addon.RefreshDots() end end)
  panel.dotOffset = slider(panel, "Distance below the health bar", -370, 0, 30,
    function() return Addon.db.dotOffset end,
    function(value) Addon.db.dotOffset = value; if Addon.RefreshDots then Addon.RefreshDots() end end)

  panel.refresh = function()
    if not Addon.db then return end
    local resource, current, maximum = Addon.GetResourceState()
    if resource and maximum > 0 and current == nil then
      -- The game is keeping the count to itself just now: Forever, in combat.
      resourceText:SetText(string.format("Detected: %s (count hidden by the game)", resource.name))
    elseif resource and maximum > 0 then
      resourceText:SetText(string.format("Detected: %s (%d / %d)", resource.name, current, maximum))
    elseif resource then
      resourceText:SetText("Detected: " .. resource.name .. " (inactive for this spec/form)")
    else
      resourceText:SetText("No supported resource for this class")
    end
    panel.enabled:SetChecked(Addon.db.enabled)
    panel.combatOnly:SetChecked(Addon.db.combatOnly)
    panel.dots:SetChecked(Addon.db.dots)
    panel.dotSize.Refresh()
    panel.dotOffset.Refresh()
    updateSoundText()
  end

  -- The settings framework drives a canvas panel through these; without OnRefresh
  -- the panel keeps whatever it showed when it was built, so the detected resource
  -- and the checkboxes go stale as soon as the player changes spec.
  panel.OnRefresh = panel.refresh
  panel.OnCommit = function() end
  panel.OnDefault = function()
    if Addon.RestoreDefaults then Addon.RestoreDefaults() end
    panel.refresh()
  end
  panel:SetScript("OnShow", panel.refresh)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    Addon.settingsCategory = category
    Addon.settingsCategoryID = category.GetID and category:GetID() or category.ID
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  return panel
end

function Addon.OpenSettings()
  if not Addon.settingsPanel then Addon.CreateSettingsPanel() end
  Addon.settingsPanel.refresh()
  if Settings and Settings.OpenToCategory and Addon.settingsCategoryID then
    Settings.OpenToCategory(Addon.settingsCategoryID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(Addon.settingsPanel)
    InterfaceOptionsFrame_OpenToCategory(Addon.settingsPanel)
  end
end
