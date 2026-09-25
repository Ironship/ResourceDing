-- Run from the addon root:  lua tests/dots.test.lua
--
-- The combo point dots under the target's nameplate (Dots.lua), on a fake Forever client: the
-- count in the open, the count secret in a fight, no target, a friendly one, a druid out of Cat
-- Form, the plate handed to another unit, the setting off.

local failures = 0
local function check(cond, label)
  if cond then print("ok   " .. label) else print("FAIL " .. label); failures = failures + 1 end
end

-- A value the client keeps secret: any comparison or sum raises, as it does in the game.
local SECRET = setmetatable({}, {
  __lt = function() error("compared a secret") end, __le = function() error("compared a secret") end,
  __add = function() error("did sums with a secret") end, __sub = function() error("did sums with a secret") end,
  __concat = function() error("concatenated a secret") end,
})
function issecretvalue(v) return rawequal(v, SECRET) end

local frames = {}
local function frame(kind, parent)
  local f = { kind = kind, parent = parent, shown = true, points = {}, events = {}, textures = {} }
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
  function f:CreateTexture()
    local t = { SetTexture = function() end, SetVertexColor = function() end, ClearAllPoints = function() end,
      SetPoint = function() end, SetAllPoints = function() end }
    self.textures[#self.textures + 1] = t
    return t
  end
  function f:SetStatusBarTexture() end
  function f:SetStatusBarColor() end
  function f:SetMinMaxValues(a, b) self.min, self.max = a, b end
  function f:SetValue(v) self.value = v end
  frames[#frames + 1] = f
  return f
end

UIParent = frame("UIParent")
function CreateFrame(kind, _, parent) return frame(kind, parent) end
C_Timer = { After = function() end }
SlashCmdList = {}
strlower, strtrim = string.lower, function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
Enum = { PowerType = { ComboPoints = 4 } }
SOUNDKIT = { AUCTION_WINDOW_OPEN = 5274 }
function GetBuildInfo() return "1.60.1", "70009", "", 16001 end -- Forever: the Classic game
function PlaySound() return true end
function UnitAffectingCombat() return false end
class = "ROGUE"
function UnitClass() return "Schurke", class end
form = nil
function GetShapeshiftFormID() return form end
points = 0
function UnitPower() return points end
function UnitPowerMax() return 5 end
target = { hostile = true }
function UnitExists(unit) return unit == "target" and target ~= nil end
function UnitCanAttack() return target ~= nil and target.hostile end
function UnitIsDeadOrGhost() return false end
plate = frame("plate")
plate.UnitFrame = { healthBar = frame("healthBar", plate) }
C_NamePlate = { GetNamePlateForUnit = function(unit) if unit == "target" or unit == "nameplate1" then return plate end end }

local ns = {}
assert(loadfile("Core.lua"))("ResourceDing", ns)
assert(loadfile("Dots.lua"))("ResourceDing", ns)
local addon = _G.ResourceDing
local events -- Core's event frame: the first frame with an OnEvent
for _, f in ipairs(frames) do if f.OnEvent and not events then events = f end end
events.OnEvent(events, "ADDON_LOADED", "ResourceDing")

local row = addon._dotsRow()
local dots = addon._dots
local function fire(event, ...)
  for _, f in ipairs(frames) do
    if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
  end
end
local function full(i) return dots[i].value ~= nil and not issecretvalue(dots[i].value) and dots[i].value >= dots[i].max end

check(row ~= nil, "the dots start with the settings loaded")
check(addon.db.dots == true and addon.db.dotSize == 14, "on by default, 14 across")

points = 3
fire("UNIT_POWER_FREQUENT", "player")
check(row.shown and row.parent == plate, "a hostile target: the dots on its plate")
check(#dots == 5 and dots[5].shown, "five dots for five points")
check(dots[1].min == 0 and dots[1].max == 1 and dots[5].min == 4 and dots[5].max == 5, "each dot a bar from n - 1 to n")
check(full(1) and full(2) and full(3) and not full(4) and not full(5), "3 points: the first three full")
check(row.points[1][1] == "TOP" and row.points[1][2] == plate.UnitFrame.healthBar and row.points[1][5] == -2,
  "under the plate's health bar, 2 below")

-- in a fight the client keeps the count secret, and Blizzard's display is not there to read
points = SECRET
local ok, err = pcall(fire, "UNIT_POWER_FREQUENT", "player")
check(ok, "a secret count raises nothing: " .. tostring(err))
check(issecretvalue(dots[1].value) and issecretvalue(dots[5].value), "the secret goes to the bars as it is, for them to show")
check(row.shown, "and the dots stay shown")

points = 2
target = { hostile = false }
fire("PLAYER_TARGET_CHANGED")
check(not row.shown and row.parent == UIParent, "a friendly target: no dots, and off its plate")
target = nil
fire("PLAYER_TARGET_CHANGED")
check(not row.shown, "no target: no dots")

target = { hostile = true }
class = "DRUID"
form = nil
fire("UPDATE_SHAPESHIFT_FORM")
check(not row.shown, "a druid out of Cat Form: no dots")
form = 1
fire("UPDATE_SHAPESHIFT_FORM")
check(row.shown and full(2) and not full(3), "a druid in Cat Form: the dots")

fire("NAME_PLATE_UNIT_REMOVED", "nameplate7")
check(row.shown and row.parent == plate, "another plate going away changes nothing")
local held = plate
C_NamePlate.GetNamePlateForUnit = function(unit) if unit == "nameplate1" then return held end end
fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(not row.shown and row.parent == UIParent, "the target's plate freed: the dots leave it at once")

C_NamePlate.GetNamePlateForUnit = function(unit) if unit == "target" then return plate end end
addon.db.dots = false
fire("PLAYER_TARGET_CHANGED")
check(not row.shown, "switched off in the settings: no dots")
addon.db.dots, addon.db.dotSize = true, 20
fire("PLAYER_TARGET_CHANGED")
check(row.shown and dots[1].width == 20, "a new size is laid out")

print(failures == 0 and "dots: ok" or ("dots: " .. failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
