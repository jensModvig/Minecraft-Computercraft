
-- A pose consists of x,y,z coordinate and an optional direction.
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
    copy = function(self)
        return new(self.x, self.y, self.z, self.f)
    end,
    tostring = function(self)
        return self.x .. "," .. self.y .. "," .. self.z .. "," .. (self.f and self.f or "nil") 
    end,
    move_distance = function(self, o)
        return math.abs(self.x - o.x) + math.abs(self.y - o.y) + math.abs(self.z - o.z)
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
        f = tonumber(f)
    }, poseMetatable)
end

return {new = new}