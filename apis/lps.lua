local pose = require("/apis/pose")
local options = require("/apis/persistanceOptions")
local data = options.load("lps")

local dir_map = {
    vector.new(1,0,0), -- north/front
    vector.new(0,0,1), -- east/right
    vector.new(-1,0,0),-- south/back
    vector.new(0,0,-1) -- west/left
}

local lPose = pose.new(0,0,0,1)
local onMoveFunc

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
    lPose = lPose:add(dir_map[lPose.f]:mul(relative.x)):add(vector.new(0,relative.y,0))
    if (onMoveFunc) then
      onMoveFunc()
    end
end
local function forward() return move(turtle.forward, turtle.dig, turtle.attack, turtle.detect, vector.new(1,0,0)) end
local function up() return move(turtle.up, turtle.digUp, turtle.attackUp, turtle.detectUp, vector.new(0,1,0)) end
local function down() return move(turtle.down, turtle.digDown, turtle.attackDown, turtle.detectDown, vector.new(0,-1,0)) end

local function turn(action, moduloOffset)
  action()
  lPose.f = (lPose.f + moduloOffset) % 4 + 1
end
local function turnRight() turn(turtle.turnRight, 0) end
local function turnLeft() turn(turtle.turnLeft, 2) end

local function face(goal)
  if goal%4+1 == lPose.f then
    turnLeft()
  else
    for i=1,math.abs(goal-(lPose.f%4))%4 do
      turnRight()
    end
  end
end

data.waypoints = {}
local function gotoPose(x, y, z, f)
    print("going to:", pose.new(x, y, z, f):tostring())
    function travelAxis(difference, action, facing)
        if difference == 0 then return end
        face(facing)
        for i=1,math.abs(difference) do
            action()
        end
    end
    travelAxis(x - lPose.x, forward, x < lPose.x and 3 or 1)
    travelAxis(z - lPose.z, forward, z < lPose.z and 4 or 2)
    travelAxis(y - lPose.y, y < lPose.y and down or up, lPose.f)
    if (f) then
      print("requested a facing", f)
      face(f)
    end
end
local function getPose() return lPose:copy() end
local function registerOnMove(onMove)
  onMoveFunc = onMove
end

function sign(number)
  return (number > 0 and 1) or (number == 0 and 0) or -1
end

local function calculatePose()
  local fuelLeft = data.startFuel
  local ourPose = pose.new(0, 0, 0, 1)

  function travelAxis(difference, facing, axis)
    ourPose.f = facing
    if fuelLeft == turtle.getFuelLevel() then
      return true
    end
    local stepsMoved = math.min(math.abs(difference), fuelLeft - turtle.getFuelLevel())
    fuelLeft = fuelLeft - stepsMoved
    ourPose[axis] = ourPose[axis] + math.sign(difference)*stepsMoved
  end
    -- backtrack until we find position and facing
  local i = 1
  while data.waypoints[i+1] and data.startFuel > fuelLeft do
    local prvW, nxtW = data.waypoints[i-1], data.waypoints[i]
    if travelAxis(prvW.x - nxtW.x, prvW.x < nxtW.x and 3 or 1, "x") or
    travelAxis(prvW.z - nxtW.z, prvW.z < nxtW.z and 4 or 2, "z") or
    travelAxis(prvW.y - nxtW.y, ourPose.f, "y") then end
    i = i + 1
  end
  return {
    pose = ourPose,
    nxtWaypointIdx = i - 1
  }
end

if data then
    local calc = calculatePose()
    lPose = pose.new(calc.pose)
    local i = 0
    data.waypoints[1] = pose.new(calc.pose)
    while data.waypoints[calc.nxtWaypointIdx + i] do
      data.waypoints[i + 2] = data.waypoints[calc.nxtWaypointIdx + i]
      data.waypoints[calc.nxtWaypointIdx + i] = nil
      i = i + 1
    end
    data.startFuel = turtle.getFuelLevel()
    options.save(data, "lps")
end


local function navigate(success, error)
  data.startFuel = turtle.getFuelLevel()
  options.save(data, "lps")
  local status, err = pcall(function()--try
    for _, v in pairs(data.waypoints) do
      gotoPose(v.x, v.y, v.z, v.f)
    end
    callback()
  end ) if not status then-- catch
    error(err)
  end
end

return {
  forward = forward,
  up = up,
  down = down,
  turnRight = turnRight,
  turnLeft = turnLeft,
  face = face,
  gotoPose = gotoPose,
  getPose = getPose,
  registerOnMove = registerOnMove,
  navigate=navigate,
  waypoints=data.waypoints
}