-- Base Creature class for all catchable creatures
local Creature = {}
Creature.__index = Creature

function Creature:new(name, level, maxHp, attack, speed)
    local self = setmetatable({}, self)

    -- Basic creature properties
    self.name = name
    self.level = level or 1
    self.experience = 0
    self.experienceToNextLevel = 100 * self.level

    -- Base stats
    self.baseStats = {
        hp = maxHp or 20,
        attack = attack or 5,
        speed = speed or 5
    }

    -- Current stats (can be modified by status effects)
    self.stats = {
        hp = self.baseStats.hp,
        attack = self.baseStats.attack,
        speed = self.baseStats.speed
    }

    -- Current HP
    self.currentHp = self.stats.hp

    -- Moves
    self.moves = {}
    self.maxMoves = 4

    -- Sprite
    self.spriteSheet = nil
    self.animations = {
        idle = {},
        attack = {},
        hurt = {}
    }

    return self
end

-- Add a move to this creature
function Creature:learnMove(move)
    if #self.moves >= self.maxMoves then
        -- Cannot learn more than maxMoves
        return false, "This creature already knows " .. self.maxMoves .. " moves."
    end

    table.insert(self.moves, move)
    return true
end

-- Replace a move at specific index
function Creature:replaceMove(index, move)
    if index < 1 or index > #self.moves then
        return false, "Invalid move index."
    end

    self.moves[index] = move
    return true
end

-- Get move at specific index
function Creature:getMove(index)
    if index < 1 or index > #self.moves then
        return nil
    end

    return self.moves[index]
end

-- Apply damage to this creature
function Creature:takeDamage(amount)
    self.currentHp = math.max(0, self.currentHp - amount)
    return self.currentHp <= 0
end

-- Heal this creature
function Creature:heal(amount)
    self.currentHp = math.min(self.stats.hp, self.currentHp + amount)
end

-- Reset creature to full health
function Creature:fullHeal()
    self.currentHp = self.stats.hp
end

-- Add experience points and check for level up
function Creature:addExperience(amount)
    self.experience = self.experience + amount

    -- Check for level up
    local leveledUp = false
    while self.experience >= self.experienceToNextLevel do
        self:levelUp()
        leveledUp = true
    end

    return leveledUp
end

-- Level up the creature
function Creature:levelUp()
    self.level = self.level + 1
    self.experience = self.experience - self.experienceToNextLevel
    self.experienceToNextLevel = 100 * self.level

    -- Increase stats
    local hpIncrease = math.random(2, 5)
    local attackIncrease = math.random(1, 2)
    local speedIncrease = math.random(1, 2)

    self.baseStats.hp = self.baseStats.hp + hpIncrease
    self.baseStats.attack = self.baseStats.attack + attackIncrease
    self.baseStats.speed = self.baseStats.speed + speedIncrease

    -- Update current stats
    self.stats.hp = self.baseStats.hp
    self.stats.attack = self.baseStats.attack
    self.stats.speed = self.baseStats.speed

    -- Also heal the creature by the HP increase amount
    self.currentHp = self.currentHp + hpIncrease
end

-- Calculate damage based on attacker's stats and move power
function Creature:calculateDamage(move, defender)
    local power = move.power
    local attackStat = self.stats.attack
    local baseDamage = (power * attackStat / 50) + 2

    -- Add a random factor (0.85 to 1.00)
    local randomFactor = 0.85 + math.random() * 0.15

    return math.floor(baseDamage * randomFactor)
end

-- Draw the creature (to be overridden by subclasses)
function Creature:draw(x, y, scale)
    -- Default drawing method if no specific implementation
    love.graphics.setColor(1, 1, 1)
    if self.spriteSheet then
        -- Draw from sprite sheet based on current animation frame
        -- This would need to be implemented by each specific creature
    else
        -- Draw a placeholder
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.rectangle("fill", x - 20, y - 20, 40, 40)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(self.name, x - 10, y - 10)
    end
end

-- Update the creature's state (animation, etc.)
function Creature:update(dt)
    -- Animation updates would go here
end

return Creature