local pose = {
    add = function(self, o)
        return pose.new(
            self.x + o.x,
            self.y + o.y,
            self.z + o.z
        )
    end,
    tostring = function(self)
        return self.x .. "," .. self.y .. "," .. self.z .. "," .. self.f
    end
}
local poseMetatable = {
    __index = pose,
    __add = pose.add,
    __tostring = pose.tostring
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

local lPose = pose.new()

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
    coords = coords:add(dir_map[coords.f]:mul(relative.x)):add(vector.new(0,relative.y,0))
end
local function forward() return move(turtle.forward, turtle.dig, turtle.attack, turtle.detect, vector.new(1,0,0)) end
local function up() return move(turtle.up, turtle.digUp, turtle.attackUp, turtle.detectUp, vector.new(0,1,0)) end
local function down() return move(turtle.down, turtle.digDown, turtle.attackDown, turtle.detectDown, vector.new(0,-1,0)) end

local function turn(action, moduloOffset)
  action()
  lpose.f = (lpose.f + moduloOffset) % 4 + 1
end
local function turnRight() turn(turtle.turnRight, 0) end
local function turnLeft() turn(turtle.turnLeft, 2) end

local function face(goal)
  if goal%4+1 == lpose.f then
    turnLeft()
  else
    for i=1,math.abs(goal-(lpose.f%4)) do
      turnRight()
    end
  end
end

local function gotoPose(x, y, z, f)
    local LUT = {
        -- action to perform | direction to face
        { action = forward, facing = x < lpose.x and 3 or 1 },
        { action = y < lpose.y and down or up, facing = lpose.f },
        { action = forward, facing = z < lpose.z and 4 or 2 }
    }
    function travelAxis(difference, axis)
        if difference == 0 then return end
        face(LUT[axis].facing)
        for i=1,math.abs(difference) do
            LUT[axis].action()
        end
    end
    travelAxis(y - lpose.y, 2)
    travelAxis(z - lpose.z, 3)
    travelAxis(x - lpose.x, 1)
    face(f)
end

local params = parser.parse({ ... }, {{"x"}, {"y"}, {"z"}, {"f"}}, {})
gotoPose(params.x, params.y, params.z, params.f)