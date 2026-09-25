-- A sound when mana climbs to a level: a caster drinking need not watch the bar. 100% by default,
-- 80% for a warlock, who takes the rest with Life Tap.
--
-- Only while the client shows the mana: on WoW Forever the player's power can be secret in a
-- fight, and a level that cannot be read is not guessed. A reading the client withholds also
-- forgets the last one, so mana that climbed unseen does not ding late when it shows again.

local _, Addon = ...

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local QUIET_AFTER_WORLD = 3

local below -- was mana below the level at the last reading? nil: no reading to go by
local quietUntil = 0

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) or false end

local function plainNumber(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok or isSecret(v) or type(v) ~= "number" then return nil end
  return v
end

-- The level for a class when it has none saved: 80 for a warlock, 100 for anyone else.
function Addon.DefaultManaPercent()
  local _, class = UnitClass("player")
  return class == "WARLOCK" and 80 or 100
end

function Addon.CheckMana()
  if not (Addon.db and Addon.db.mana) then return end
  local current, maximum = plainNumber(UnitPower, "player", MANA), plainNumber(UnitPowerMax, "player", MANA)
  if current == nil or maximum == nil then below = nil return end
  if maximum <= 0 then return end -- no mana: a warrior, a rogue
  local reached = current * 100 >= maximum * Addon.db.manaPercent
  if below == true and reached and GetTime() >= quietUntil then Addon.PlaySoundKey(Addon.db.manaSound) end
  below = not reached
end

-- A new level in the settings: the next reading only takes note, it does not ding.
function Addon.ResetMana() below = nil end

local function start()
  local events = CreateFrame("Frame")
  pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
  for _, event in ipairs({ "UNIT_POWER_UPDATE", "UNIT_MAXPOWER" }) do
    pcall(events.RegisterUnitEvent, events, event, "player")
  end
  events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      quietUntil = GetTime() + QUIET_AFTER_WORLD
      below = nil
    end
    Addon.CheckMana()
  end)
  Addon.CheckMana()
end

Addon.starters = Addon.starters or {}
table.insert(Addon.starters, start)
