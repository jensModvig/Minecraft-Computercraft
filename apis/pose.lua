local pose = {
    add = function(self, o)
        return vector.new(
            self.x + o.x,
            self.y + o.y,
            self.z + o.z
        )
    end,
    tostring = function(self)
        return self.x .. "," .. self.y .. "," .. self.z .. "," self.f
    end
}
local poseMetatable = {
    __index = vector,
    __add = vector.add,
    __tostring = vector.tostring
}

function new(x, y, z, f)
    return setmetatable({
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        z = tonumber(z) or 0,
        f = tonumber(f) or 1,
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
    coords = coords:add(dir_map[dir]:mul(relative.x)):add(vector.new(0,relative.y,0))
end