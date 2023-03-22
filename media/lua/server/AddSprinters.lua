local AS = AddSprinters

-- imports
local ZombRand = ZombRand
local getClassField = getClassField
local getClassFieldVal = getClassFieldVal
local getGameTime = getGameTime
local getSandboxOptions = getSandboxOptions

-- percentages
local BASE_RATIO = 100
local SHAMBLER_PERCENTAGE = SandboxVars.AddSprinters.ShamblerProbability					
local SPRINTER_PERCENTAGE_BY_DAY = SandboxVars.AddSprinters.SprinterProbabilityDay 				
local SPRINTER_PERCENTAGE_BY_NIGHT = SandboxVars.AddSprinters.SprinterProbabilityNight 			

-- day night hours
local DAY_STARTS = 5
local NIGHT_STARTS = 23

-- speed types
local SPRINTER = 1
local FAST_SHAMBLER = 2
local SHAMBLER = 3

-- HEALTH modifiers 
local SPRINTER_HEALTH_MODIFIER = SandboxVars.AddSprinters.SprinterHealthModifier			
local SHAMBLER_HEALTH_MODIFIER = SandboxVars.AddSprinters.ShamblerHealthModifier				
local FAST_SHAMBLER_HEALTH_MODIFIER = SandboxVars.AddSprinters.FastShamblerHealthModifier
local ZOMBIE_PLAYER_HEALTH_MODIFIER = SandboxVars.AddSprinters.ZombiePlayerHealthModifier
			
local ZOMBIE_HEALTH_RANGE = 200
local ZOMBIE_HEALTH_PRECISION = 1000.0

function AS.findField(o, fname)
  for i = 0, getNumClassFields(o) - 1 do
    local f = getClassField(o, i)
    if tostring(f) == fname then
      return f
    end
  end
end

local function zombieID(zombie)
    local id = zombie:getOnlineID()
    if id == -1 then
      id = zombie:hashCode()
    else
      id = Double.new(id):hashCode()
    end
    --print("zombie id: "..id)
    return math.abs(id)
end


local function generateZombieHealth(range, precision, healthModifier)
    return ((ZombRand(range)+(precision-(range/2)))/precision)*healthModifier
end

local function getHealthModifier(speedType)
	if speedType == FAST_SHAMBLER then return FAST_SHAMBLER_HEALTH_MODIFIER
	elseif speedType == SHAMBLER then return SHAMBLER_HEALTH_MODIFIER end
	return SPRINTER_HEALTH_MODIFIER
end

local function updateSpeed(zombie, target_speed, speedTypeField)
    local actual_speed = getClassFieldVal(zombie, speedTypeField)
	if actual_speed == FAST_SHAMBLER and target_speed == FAST_SHAMBLER then
		zombie:makeInactive(true)
        zombie:makeInactive(false)
	end
    if actual_speed ~= target_speed then
        getSandboxOptions():set("ZombieLore.Speed", target_speed)
        zombie:makeInactive(true)
        zombie:makeInactive(false)
        getSandboxOptions():set("ZombieLore.Speed", FAST_SHAMBLER)
		local healthModifier = getHealthModifier(target_speed)
        zombie:setHealth(generateZombieHealth(ZOMBIE_HEALTH_RANGE, ZOMBIE_HEALTH_PRECISION, healthModifier))
		--print("HP: "..zombie:getHealth())
    end
	
end

local function getSprinterPercentage()
    local currentHour = getGameTime():getTimeOfDay()
    if currentHour >= NIGHT_STARTS or currentHour < DAY_STARTS then
        return SPRINTER_PERCENTAGE_BY_NIGHT
    end
    return SPRINTER_PERCENTAGE_BY_DAY
end

local function getDistribution()
    local sprinterPercentage = getSprinterPercentage()
    local distribution = {}
    distribution.Shambler = SHAMBLER_PERCENTAGE
    distribution.FastShambler = BASE_RATIO - sprinterPercentage
    distribution.Sprinter = distribution.FastShambler + sprinterPercentage
    return distribution
end

local function updateZombiePlayer(zombie, player)
--print("PLAYER USERNAME: "..player:getDisplayName().." AccessLeveL: "..player:getAccessLevel())
  if player:getAccessLevel() ~= "None" and player:getDisplayName() == "GM" then
    local modData = zombie:getModData()
    if not modData.ZPSet then
      zombie:setSkeleton(true)
      zombie:setHealth(generateZombieHealth(ZOMBIE_HEALTH_RANGE, ZOMBIE_HEALTH_PRECISION, ZOMBIE_PLAYER_HEALTH_MODIFIER))
      --print("ZPHP: "..zombie:getHealth())
      modData.ZPSet = 1
    end
  end
end

local function setRandomSprinter(zombie, distribution, speedTypeField)
    local slice = zombieID(zombie) % 100
    if slice < distribution.Shambler then
        updateSpeed(zombie, SHAMBLER, speedTypeField)
    elseif slice < distribution.FastShambler then
        updateSpeed(zombie, FAST_SHAMBLER, speedTypeField)
    elseif slice < distribution.Sprinter then
        updateSpeed(zombie, SPRINTER, speedTypeField)
    end
	local player = zombie:getReanimatedPlayer()
    if player then
		  updateZombiePlayer(zombie, player)
    end
end

local tickFrequency = 10
local lastTicks = {}
local lastTicksIdx = 1
local last = getTimestampMs()
local tickCount = 0
local function updateAllZombies()
  tickCount = tickCount + 1
  if tickCount % tickFrequency ~= 1 then
    return
  end
  tickCount = 1

  local now = getTimestampMs()
  local diff = now - last
  last = now

  local tickMs = diff / tickFrequency
  lastTicks[lastTicksIdx] = tickMs
  lastTicksIdx = (lastTicksIdx % 5) + 1
  local totalTicks = 0
  local sumTicks = 0
  for i, v in ipairs(lastTicks) do
    sumTicks = sumTicks + v
    totalTicks = totalTicks + 1
  end
	local speedTypeField = AS.findField(IsoZombie.new(nil), "public int zombie.characters.IsoZombie.speedType")
  local avgTickMs = sumTicks / totalTicks
  -- NOTE: needs to be at least 2 for modulo check to pass
  tickFrequency = math.max(2, math.ceil(SandboxVars.AddSprinters.Frequency / avgTickMs))
  local zs = getCell():getZombieList()
	local distribution = getDistribution()
  for i = 0, zs:size() - 1 do
    setRandomSprinter(zs:get(i), distribution, speedTypeField)
  end
    -- end)
end

Events.OnTick.Add(updateAllZombies)
--Events.OnZombieUpdate.Add(setRandomSprinter)
