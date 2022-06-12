local parser = require("apis/paramParser")
local params = parser.parse({ ... }, {{"x", "z"}, {"z"}}, {x="REQUIRED", z="REQUIRED"})

local startTime = os.epoch("utc")
local startFuel = turtle.getFuelLevel()

local EST_FUEL = 23.1040582726327 -- Moves
local EST_TIME = 22.6577539021852 -- Seconds
local area = params.x*params.z
local est_fuel_total = area*EST_FUEL


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

local coords = vector.new(0,0,0)
-- direction north, east, south, west
local dir = 1 --north
local dir_map = {
    vector.new(1,0,0),
    vector.new(0,0,1),
    vector.new(-1,0,0),
    vector.new(0,0,-1)
}

local function move(ahead, dig, attack, detect, relative)
    while not ahead() do
        if detect() and not dig() then
            error("cant mine block")
        end
        attack()
        if turtle.getFuelLevel() == 0 then
            error("no more fuel")
        end
    end
    coords = coords:add(dir_map[dir]:mul(relative.x)):add(vector.new(0,relative.y,0))
end
local function forward() return move(turtle.forward, turtle.dig, turtle.attack, turtle.detect, vector.new(1,0,0)) end
local function up() return move(turtle.up, turtle.digUp, turtle.attackUp, turtle.detectUp, vector.new(0,1,0)) end
local function down() return move(turtle.down, turtle.digDown, turtle.attackDown, turtle.detectDown, vector.new(0,-1,0)) end

local function turn(action, moduloOffset)
  action()
  dir = (dir + moduloOffset) % 4 + 1
end
local function turnRight() turn(turtle.turnRight, 0) end
local function turnLeft() turn(turtle.turnLeft, 2) end

local function face(goal)
  if goal%4+1 == dir then
    turnLeft()
  else
    for i=1,math.abs(goal-(dir%4)) do
      turnRight()
    end
  end
end


local function getEmptySlots()
    local count = 16
    for n=1,16 do
        if turtle.getItemCount(n) > 0 then
            count = count - 1
        end
    end
    return count
end

local resumeDir
local resumeSpot
local function goHome()
  resumeSpot = coords
  resumeDir = dir
  while coords.y < 0 do
    up()
  end
  if coords.z ~= 0 then
      face(4)--local West
      while coords.z > 0 do
        forward()
      end
  end
  face(3)--local south
  while coords.x > 0 do
    forward()
  end
end
local function resumeMining()
  if resumeSpot.x ~= coords.x then
    face(1)
    while resumeSpot.x > coords.x do
      forward()
    end
  end
  if resumeSpot.z ~= coords.z then
    face(2)
    while resumeSpot.z > coords.z do
      forward()
    end
  end
  while resumeSpot.y < coords.y do
    down()
  end
  face(resumeDir)
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
  forward()
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
          turnRight()
          mine()
          turnRight()
        else
          turnLeft()
          mine()
          turnLeft()
        end
      else
        local status, err = pcall(function()--try
            down()
            down()
            down()
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
          turnRight()
        else
          turnLeft()
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