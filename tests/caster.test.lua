-- Run from the addon root:  lua tests/caster.test.lua
--
-- The casters' part: a warlock's Soul Shards (Shards.lua) and the mana level (Mana.lua), on a fake
-- Forever client (the Classic game, where shards are items) and a fake Retail one.

local failures = 0
local function check(cond, label)
  if cond then print("ok   " .. label) else print("FAIL " .. label); failures = failures + 1 end
end

local SECRET = setmetatable({}, {
  __lt = function() error("compared a secret") end, __le = function() error("compared a secret") end,
  __add = function() error("did sums with a secret") end, __sub = function() error("did sums with a secret") end,
  __mul = function() error("did sums with a secret") end, __concat = function() error("concatenated a secret") end,
})
function issecretvalue(v) return rawequal(v, SECRET) end

local frames, played

local function frame(kind, parent)
  local f = { kind = kind, parent = parent, shown = true, points = {}, events = {} }
  function f:SetParent(p) self.parent = p end
  function f:GetParent() return self.parent end
  function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
  function f:ClearAllPoints() self.points = {} end
  function f:SetSize(w, h) self.width, self.height = w, h end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:SetShown(v) self.shown = v and true or false end
  function f:IsShown() return self.shown end
  function f:SetAllPoints() end
  function f:RegisterEvent(e) self.events[e] = true end
  function f:RegisterUnitEvent(e) self.events[e] = true end
  function f:SetScript(name, fn) self[name] = fn end
  function f:CreateTexture() return frame("texture", self) end
  function f:CreateFontString() return frame("fontstring", self) end
  function f:SetTexture(t) self.texture = t end
  function f:SetText(t) self.text = t end
  function f:SetVertexColor() end
  function f:SetStatusBarTexture() end
  function f:SetStatusBarColor() end
  function f:SetMinMaxValues() end
  function f:SetValue() end
  frames[#frames + 1] = f
  return f
end

-- One client: its version, the player's class, and what it answers.
local now, shards, mana, manaMax, class, target, plate
local function client(opts)
  frames, played = {}, {}
  now, shards, mana, manaMax = 1000, opts.shards or 3, opts.mana or 50, opts.manaMax or 100
  class = opts.class or "WARLOCK"
  target = { hostile = true }
  for _, name in ipairs({ "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "ResourceDingDB", "ResourceDing" }) do _G[name] = nil end
  if opts.retail then
    WOW_PROJECT_MAINLINE, WOW_PROJECT_ID = 1, 1
    GetBuildInfo = function() return "12.1.0", "1", "", 120100 end
  else
    GetBuildInfo = function() return "1.60.1", "70009", "", 16001 end
  end
  UIParent = frame("UIParent")
  CreateFrame = function(kind, _, parent) return frame(kind, parent) end
  C_Timer = { After = function() end }
  SlashCmdList = {}
  strlower, strtrim = string.lower, function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
  Enum = { PowerType = { ComboPoints = 4, Mana = 0, SoulShards = 7 } }
  SOUNDKIT = { AUCTION_WINDOW_OPEN = 5274, READY_CHECK = 8960 }
  GetTime = function() return now end
  PlaySound = function(id) played[#played + 1] = id return true end
  UnitAffectingCombat = function() return false end
  UnitClass = function() return class, class end
  GetShapeshiftFormID = function() return nil end
  UnitPower = function(_, power) if power == 0 then return mana end return 0 end
  UnitPowerMax = function(_, power) if power == 0 then return manaMax end return 0 end
  GetComboPoints = function() return 0 end
  C_Item = { GetItemCount = function(id) if id == 6265 then return shards end return 0 end }
  UnitExists = function(unit) return unit == "target" and target ~= nil end
  UnitCanAttack = function() return target ~= nil and target.hostile end
  UnitIsDeadOrGhost = function() return false end
  plate = frame("plate")
  plate.UnitFrame = { healthBar = frame("healthBar", plate) }
  C_NamePlate = { GetNamePlateForUnit = function(unit) if unit == "target" then return plate end end }

  local ns = {}
  for _, file in ipairs({ "Core.lua", "Dots.lua", "Shards.lua", "Mana.lua" }) do
    assert(loadfile(file))("ResourceDing", ns)
  end
  for _, f in ipairs(frames) do
    if f.OnEvent then f.OnEvent(f, "ADDON_LOADED", "ResourceDing") break end
  end
  return _G.ResourceDing
end

local function fire(event, ...)
  for _, f in ipairs(frames) do
    if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
  end
end
local function dings(id)
  local n = 0
  for _, p in ipairs(played) do if p == id then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------------------------
print("-- Soul Shards")
local addon = client({ shards = 3 })
check(dings(5274) == 0, "the shards in the bags at login: no sound")
now = now + 5
shards = 4
fire("BAG_UPDATE_DELAYED")
check(dings(5274) == 1, "a shard comes in: the sound")
fire("BAG_UPDATE_DELAYED")
check(dings(5274) == 1, "the same count again (a shard moved between bags): nothing")
shards = 3
fire("BAG_UPDATE_DELAYED")
check(dings(5274) == 1, "a shard used: nothing")

local row = addon._shardRow()
fire("PLAYER_TARGET_CHANGED")
check(row.shown and row.parent == plate, "a hostile target: the diamonds on its plate")
local shownDiamonds = 0
for _, d in ipairs(addon._diamonds) do if d.shown then shownDiamonds = shownDiamonds + 1 end end
check(shownDiamonds == 3, "one diamond per shard")
check(addon._diamonds[1].texture == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", "the purple raid diamond")
shards = 12
fire("BAG_UPDATE_DELAYED")
shownDiamonds = 0
for _, d in ipairs(addon._diamonds) do if d.shown then shownDiamonds = shownDiamonds + 1 end end
check(shownDiamonds == 10 and addon._shardMore().text == "+2", "12 shards: ten diamonds and +2")
check(dings(5274) == 2, "  and 3 to 12 is a count going up: the sound")
target = nil
fire("PLAYER_TARGET_CHANGED")
check(not row.shown and row.parent == UIParent, "no target: no diamonds")
target = { hostile = true }
addon.db.shardDiamonds = false
fire("PLAYER_TARGET_CHANGED")
check(not row.shown, "diamonds switched off: none")

fire("PLAYER_ENTERING_WORLD")
shards = 13
fire("BAG_UPDATE_DELAYED")
check(dings(5274) == 2, "right after a loading screen the bags are read, not filled: nothing")
now = now + 5
addon.db.shards = false
shards = 14
fire("BAG_UPDATE_DELAYED")
check(dings(5274) == 2, "the shard sound switched off: nothing")

addon = client({ class = "ROGUE" })
check(addon._shardRow() == nil, "a rogue: the shards never start")
addon = client({ retail = true })
check(addon._shardRow() == nil, "Retail's warlock has a shard bar instead: the items are not counted")

---------------------------------------------------------------------------------------------
print("-- mana")
addon = client({ class = "WARLOCK", mana = 50 })
check(addon.db.manaPercent == 80, "a warlock's level is 80%")
now = now + 5
mana = 79
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 0, "79%: nothing yet")
mana = 80
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 1, "80%: the mana sound, Ready Check by default")
mana = 95
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 1, "still above: once only")
mana = 60
fire("UNIT_POWER_UPDATE", "player")
mana = 85
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 2, "down and up again: again")

-- in a fight the client may keep mana secret
mana = 40
fire("UNIT_POWER_UPDATE", "player")
mana = SECRET
local ok, err = pcall(fire, "UNIT_POWER_UPDATE", "player")
check(ok, "a secret mana value raises nothing: " .. tostring(err))
mana = 90
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 2, "mana that climbed unseen does not ding when it shows again")
mana = 50
fire("UNIT_POWER_UPDATE", "player")
mana = 81
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 3, "and the next climb in the open does")

addon.db.mana = false
mana = 50
fire("UNIT_POWER_UPDATE", "player")
mana = 100
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 3, "the mana sound switched off: nothing")

addon = client({ class = "MAGE", mana = 70 })
check(addon.db.manaPercent == 100, "anyone else's level is 100%")
now = now + 5
mana = 99
fire("UNIT_POWER_UPDATE", "player")
mana = 100
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 1, "a mage at full mana: the sound")

fire("PLAYER_ENTERING_WORLD")
mana = 50
fire("UNIT_POWER_UPDATE", "player")
mana = 100
fire("UNIT_POWER_UPDATE", "player")
check(dings(8960) == 1, "right after a loading screen: nothing")

addon = client({ class = "ROGUE", manaMax = 0 })
now = now + 5
fire("UNIT_POWER_UPDATE", "player")
check(#played == 0, "a rogue has no mana: nothing")

addon = client({ class = "WARLOCK" })
addon.db.manaPercent = 95
addon.RestoreDefaults()
check(addon.db.manaPercent == 80, "Defaults gives a warlock 80% back")

print(failures == 0 and "caster: ok" or ("caster: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
