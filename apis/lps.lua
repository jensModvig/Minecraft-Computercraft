local pose = require("/apis/pose")

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

local waypoints = {}
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

local function navigate(success, error)
  local status, err = pcall(function()--try
    for _, v in pairs(waypoints) do
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
  waypoints=waypoints
}