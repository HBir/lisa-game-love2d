-- Move class for creature attacks
local Move = {}
Move.__index = Move

function Move:new(name, power, type, description)
    local self = setmetatable({}, self)

    -- Move properties
    self.name = name
    self.power = power or 10       -- Base power of the move
    self.type = type or "normal"   -- Move type (e.g., normal, fire, water)
    self.description = description or ""

    -- Additional effects (can be expanded later)
    self.statusEffect = nil
    self.statusChance = 0

    return self
end

-- Execute this move against a target
function Move:execute(user, target)
    -- Calculate damage
    local damage = user:calculateDamage(self, target)

    -- Apply damage to target
    local fainted = target:takeDamage(damage)

    -- Apply additional effects if applicable
    if self.statusEffect and math.random() <= self.statusChance then
        -- Apply status effect (not implemented yet)
    end

    -- Return results
    return {
        damage = damage,
        fainted = fainted,
        statusApplied = false -- Will be set to true if a status was applied
    }
end

-- Create some standard moves
local MoveList = {}

MoveList.Tackle = function()
    return Move:new("Tackle", 40, "normal", "A physical attack in which the user charges and slams into the target.")
end

MoveList.Scratch = function()
    return Move:new("Scratch", 40, "normal", "Hard, pointed claws rake the target.")
end

MoveList.Growl = function()
    return Move:new("Growl", 0, "normal", "The user growls in an endearing way, lowering the opponent's Attack stat.")
    -- Status effects to be implemented later
end

MoveList.Ember = function()
    return Move:new("Ember", 40, "fire", "The target is attacked with small flames. May cause a burn.")
    -- Status effects to be implemented later
end

MoveList.Bubble = function()
    return Move:new("Bubble", 40, "water", "A spray of bubbles hits the target. May lower Speed.")
    -- Status effects to be implemented later
end

MoveList.VineWhip = function()
    return Move:new("Vine Whip", 45, "grass", "The target is struck with slender, whiplike vines.")
end

return {
    Move = Move,
    MoveList = MoveList
}