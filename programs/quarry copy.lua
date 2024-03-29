local parser = require("/apis/paramParser")
local lps = require("/apis/lps")

local params = parser.parse({ ... }, {{"x", "z"}, {"z"}}, {x="REQUIRED", z="REQUIRED"})

local startTime = os.epoch("utc")
local startFuel = turtle.getFuelLevel()

local EST_FUEL = 23.1040582726327 -- Moves
local EST_TIME = 22.6577539021852 -- Seconds
local area = params.x*params.z
local est_fuel_total = area*EST_FUEL

--- Ender chest auto detection


function disp_time(time) -- time in seconds
  local days = math.floor(time / 86400)
  local hours = math.floor(time %  86400 / 3600)
  local minutes = math.floor(time % 3600 / 60)
  --local seconds = math.floor(time % 60)

  local time_str = string.format("%d days %d hours and %d minutes", days, hours, minutes)
  -- replace word if it is preceeded by a 0
  return string.gsub(time_str,"0 %a+ a?n?d? ?","")
end


print("The program is estimated to run for " .. disp_time(area * EST_TIME) .. ".")
print(string.format("The program is estimated to use %d fuel.", est_fuel_total))
print(string.format("Turtle will have %d fuel remaining.", turtle.getFuelLevel() - est_fuel_total))


-- Blacklist
local BL = {}
BL["minecraft:stone"] = true
BL["minecraft:granite"] = true
BL["minecraft:andesite"] = true
BL["minecraft:diorite"] = true
BL["minecraft:dirt"] = true
BL["minecraft:gravel"] = true
BL["minecraft:grass_block"] = true
BL["minecraft:cobblestone"] = true
BL["minecraft:crafting_table"] = true
BL["minecraft:oak_planks"] = true

BL["minecraft:netherrack"] = true
BL["minecraft:magma_block"] = true
BL["minecraft:blackstone"] = true
BL["minecraft:soul_sand"] = true
BL["minecraft:soul_soil"] = true

BL["create:limestone"] = true
BL["create:limestone_cobblestone"] = true


local function getEmptySlots()
    local count = 16
    for n=1,16 do
        if turtle.getItemCount(n) > 0 then
            count = count - 1
        end
    end
    return count
end

local resumePose

local function goHome()
  resumePose = lps.getPose()
  lps.gotoPose(0, 0, 0, 3)
end
local function resumeMining()
  lps.gotoPose(resumePose.x, resumePose.y, resumePose.z, resumePose.f)
end
local function unload()
  for i = 1,16 do
    turtle.select(i)
    turtle.drop(64)
  end
  turtle.select(1)
end

local mustTurnRight = true

local function mine()
  local function unloadIfNecessary()
    if getEmptySlots() == 0 then
      for n=1,16 do
        if BL[turtle.getItemDetail(n).name] then
          turtle.select(n)
          turtle.dropDown(64)
        end
      end
      turtle.select(1)
      if getEmptySlots() < 3 then
        goHome()
        unload()
        resumeMining()
      end
    end
  end
  local above = { turtle.inspectUp() }
  local below = { turtle.inspectDown() }
  if not BL[above[2].name] then
    turtle.digUp()
    unloadIfNecessary()
  end
  if not BL[below[2].name] then
    turtle.digDown()
    unloadIfNecessary()
  end
  lps.forward()
  unloadIfNecessary()
end


local status, err = pcall(function()--try
  while true do
    for i = 1, params.z do
      for j = 2, params.x do
        mine()
      end
      if i < params.z then
        if mustTurnRight then
          lps.turnRight()
          mine()
          lps.turnRight()
        else
          lps.turnLeft()
          mine()
          lps.turnLeft()
        end
      else
        local status, err = pcall(function()--try
            lps.down()
            lps.down()
            lps.down()
        end ) if not status then-- catch
          goHome()
          unload()
          print("we reached bedrock")
          print("took", os.epoch("utc") - startTime, "milliseconds.")
          print("and", turtle.getFuelLevel() - startFuel, "fuel.")
          sleep(10000000)
          return
        end
        if not mustTurnRight then
          lps.turnRight()
        else
          lps.turnLeft()
        end
      end
      mustTurnRight = not mustTurnRight
    end
  end
end ) if not status then-- catch
  goHome()
  unload()
  error(err)
end