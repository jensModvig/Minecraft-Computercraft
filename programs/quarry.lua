local parser = require("/apis/paramParser")
local lps = require("/apis/lps")
local pose = require("/apis/pose")
local options = require("/apis/persistanceOptions")

local params = parser.parse({ ... }, {{"x", "z"}, {"z"}}, {
  x="REQUIRED",
  z="REQUIRED",
  resume=false
})

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


local data = options.load("quarry")
local BL = {}
for _, entry in ipairs(data.blacklist) do
  BL[entry] = true
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
  unloadIfNecessary()
end
mine()
lps.registerOnMove(mine)


if not params.resume then
    local maxX, maxZ = params.x-1, params.z-1
    local maxDepth = 255
    local pattern = params.z % 2 == 0 and 12 or 6

    lps.waypoints = {}

    for j=0,-maxDepth,-3 do
        local r = j % pattern
        local thisAxis, otherAxis, func
        if r == 0 or r == 6 then -- travelX
          thisAxis, otherAxis, func = maxX, maxZ, function(i)
            table.insert(lps.waypoints, pose.new(i%2*thisAxis, j, i));
            table.insert(lps.waypoints, pose.new((i+1)%2*thisAxis, j, i));
          end
        else
          thisAxis, otherAxis, func = maxZ, maxX, function(i)
            table.insert(lps.waypoints, pose.new(i, j, (i+1)%2*otherAxis));
            table.insert(lps.waypoints, pose.new(i, j, i%2*otherAxis));
          end
        end
        local start, finish, incr = 0, otherAxis, 1
        if r == 6 or r == 3 then
          start, finish, incr = otherAxis, 0, -1
        end
        for i=0,otherAxis do
          func(i)
        end
    end
    data.running = true
    options.save(data, "quarry")
end

lps.navigate(
  function()
    print("done")
  end,
  function(error)
    goHome()
    unload()
    print("we reached bedrock")
    print("took", os.epoch("utc") - startTime, "milliseconds.")
    print("and", turtle.getFuelLevel() - startFuel, "fuel.")
    sleep(10000000)
  end
)
