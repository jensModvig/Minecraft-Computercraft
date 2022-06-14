local Pose = {
    add = function(self, o)
        return new(
            self.x + o.x,
            self.y + o.y,
            self.z + o.z,
            self.f
        )
    end,
    mul = function(self, n)
        return new(
            self.x + n,
            self.y + n,
            self.z + n,
            self.f
        )
    end,
    tostring = function(self)
        return self.x .. "," .. self.y .. "," .. self.z .. "," .. self.f
    end
}
local poseMetatable = {
    __index = Pose,
    __add = Pose.add,
    __mul = Pose.mul,
    __tostring = Pose.tostring
}

function new(x, y, z, f)
    return setmetatable({
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        z = tonumber(z) or 0,
        f = tonumber(f) or 1
    }, poseMetatable)
end

local dir_map = {
    vector.new(1,0,0), -- north
    vector.new(0,0,1), -- east
    vector.new(-1,0,0),-- south
    vector.new(0,0,-1) -- west
}

local lPose = new()

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
    for i=1,math.abs(goal-(lPose.f%4)) do
      turnRight()
    end
  end
end

local function gotoPose(x, y, z, f)
    function travelAxis(difference, action, facing)
        if difference == 0 then return end
        face(facing)
        for i=1,math.abs(difference) do
            action()
        end
    end
    travelAxis(y - lPose.y, y < lPose.y and down or up, lPose.f)
    travelAxis(z - lPose.z, forward, z < lPose.z and 4 or 2)
    travelAxis(x - lPose.x, forward, x < lPose.x and 3 or 1)
    face(f)
end

local parser = require("/apis/paramParser")
local params = parser.parse({ ... }, {{"x"}, {"y"}, {"z"}, {"f"}}, {})
gotoPose(params.x, params.y, params.z, params.f)