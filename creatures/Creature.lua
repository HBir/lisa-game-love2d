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

    -- Sprite and animation
    self.spriteSheet = nil
    self.animations = {
        idle = {}
    }

    -- Animation state
    self.currentAnimation = "idle"
    self.animationFrame = 1
    self.animationTimer = 0
    self.animationFrameTime = 0.2 -- Default frame time (seconds)

    -- Visual effect states for attacks and damage
    self.isFlashing = false
    self.flashTimer = 0
    self.flashDuration = 0.5
    self.flashRate = 0.1 -- How fast to alternate colors

    -- Movement effect for attacks
    self.isAttacking = false
    self.attackTimer = 0
    self.attackDuration = 0.5
    self.attackOffset = {x = 0, y = 0}
    self.attackDirection = {x = 0, y = 0}
    self.maxAttackDistance = 20

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
    -- Start flashing effect when taking damage
    self:startFlashing()
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

-- Start the flashing effect when taking damage
function Creature:startFlashing()
    self.isFlashing = true
    self.flashTimer = 0
end

-- Start the attack movement effect
function Creature:startAttackAnimation(isPlayerCreature)
    self.isAttacking = true
    self.attackTimer = 0

    -- Set direction based on whether this is the player's creature or enemy
    if isPlayerCreature then
        self.attackDirection = {x = 1, y = -0.5} -- Player attacks upward and to the right
    else
        self.attackDirection = {x = -1, y = 0.5} -- Enemy attacks downward and to the left
    end
end

-- Draw the creature (to be overridden by subclasses)
function Creature:draw(x, y, scale, isPlayerCreature)
    scale = scale or 1

    -- If we're in an attack animation and the isPlayerCreature parameter was passed,
    -- update our attack direction
    if self.isAttacking and isPlayerCreature ~= nil then
        -- Update direction based on the parameter passed from BattleSystem
        if isPlayerCreature then
            self.attackDirection = {x = 1, y = -0.5} -- Player attacks upward and to the right
        else
            self.attackDirection = {x = -1, y = 0.5} -- Enemy attacks downward and to the left
        end
    end

    -- Apply attack movement offset
    local drawX = x + self.attackOffset.x
    local drawY = y + self.attackOffset.y

    -- Default drawing method if no specific implementation
    local alpha = 1
    local color = {1, 1, 1, alpha}

    -- Determine color based on flashing state
    if self.isFlashing then
        -- Flash between white and red
        if math.floor(self.flashTimer / self.flashRate) % 2 == 0 then
            color = {1, 0.3, 0.3, alpha} -- Reddish when flashing
        end
    end

    love.graphics.setColor(unpack(color))

    -- Determine if we need to mirror the sprite (enemies are mirrored)
    local scaleX = scale
    if not isPlayerCreature then
        scaleX = -scale -- Flip horizontally for enemies
    end

    if self.spriteSheet then
        -- Draw from sprite sheet based on current animation frame
        local animation = self.animations[self.currentAnimation]

        -- Check if animation exists and has frames
        if animation and animation.frames and #animation.frames > 0 then
            -- Use the current animation frame
            local frameIndex = math.min(self.animationFrame, #animation.frames)
            local frameData = animation.frames[frameIndex]

            -- Create a quad for the current frame
            local quad = love.graphics.newQuad(
                frameData.x, frameData.y,
                frameData.width, frameData.height,
                self.spriteSheet:getDimensions()
            )

            -- Draw the sprite, with scaling adjustments for mirroring
            love.graphics.draw(
                self.spriteSheet,
                quad,
                drawX, drawY,
                0, -- rotation
                scaleX, scale, -- horizontal scale might be flipped
                frameData.width / 2, frameData.height / 2 -- center origin
            )
        else
            -- Fallback to default chicken idle frames if the animation is missing
            -- Define default chicken animation frames (hardcoded fallback)
            local chickenFrames = {
                { x = 7, y = 16, width = 17, height = 16 },
                { x = 39, y = 16, width = 17, height = 16 },
                { x = 71, y = 16, width = 17, height = 16 },
                { x = 103, y = 16, width = 17, height = 16 }
            }

            -- Use a mod operation to cycle through the frames based on animation timer
            local frameIndex = math.floor((love.timer.getTime() * 5) % #chickenFrames) + 1
            local frameData = chickenFrames[frameIndex]

            -- Create a quad for the default frame
            local quad = love.graphics.newQuad(
                frameData.x, frameData.y,
                frameData.width, frameData.height,
                self.spriteSheet:getDimensions()
            )

            -- Draw the sprite, with scaling adjustments for mirroring
            love.graphics.draw(
                self.spriteSheet,
                quad,
                drawX, drawY,
                0, -- rotation
                scaleX, scale, -- horizontal scale might be flipped
                frameData.width / 2, frameData.height / 2 -- center origin
            )
        end
    else
        -- Draw a placeholder
        love.graphics.setColor(1, 0.5, 0.5)
        -- For the placeholder, we need to adjust the rectangle position when mirrored
        local rectX = drawX - 20 * math.abs(scaleX)
        love.graphics.rectangle("fill", rectX, drawY - 20 * scale, 40 * math.abs(scaleX), 40 * scale)
        love.graphics.setColor(1, 1, 1)
        -- For text, we can just center it
        love.graphics.print(self.name, drawX - 10 * math.abs(scaleX), drawY - 10 * scale, 0, math.abs(scaleX), scale)
    end
end

-- Update the creature's state (animation, etc.)
function Creature:update(dt)
    -- Update idle animation
    if self.spriteSheet then
        local animation = self.animations[self.currentAnimation]

        if animation and animation.frames and #animation.frames > 0 then
            -- Update animation timer
            self.animationTimer = self.animationTimer + dt

            -- Get frame time (either from animation or use default)
            local frameTime = animation.frameTime or self.animationFrameTime

            -- Advance frame if needed
            if self.animationTimer >= frameTime then
                self.animationTimer = self.animationTimer - frameTime
                self.animationFrame = self.animationFrame + 1

                -- Loop animation
                if self.animationFrame > #animation.frames then
                    self.animationFrame = 1
                end
            end
        end
        -- For missing animations, we'll use the global timer for animation
        -- which is handled in the draw method
    end

    -- Update flash effect
    if self.isFlashing then
        self.flashTimer = self.flashTimer + dt
        if self.flashTimer >= self.flashDuration then
            self.isFlashing = false
            self.flashTimer = 0
        end
    end

    -- Update attack movement effect
    if self.isAttacking then
        self.attackTimer = self.attackTimer + dt

        -- First half of animation - move forward
        if self.attackTimer < self.attackDuration / 2 then
            local progress = self.attackTimer / (self.attackDuration / 2)
            self.attackOffset.x = self.attackDirection.x * self.maxAttackDistance * progress
            self.attackOffset.y = self.attackDirection.y * self.maxAttackDistance * progress
        -- Second half - return to original position
        else
            local progress = (self.attackTimer - self.attackDuration / 2) / (self.attackDuration / 2)
            self.attackOffset.x = self.attackDirection.x * self.maxAttackDistance * (1 - progress)
            self.attackOffset.y = self.attackDirection.y * self.maxAttackDistance * (1 - progress)
        end

        -- End attack animation
        if self.attackTimer >= self.attackDuration then
            self.isAttacking = false
            self.attackTimer = 0
            self.attackOffset = {x = 0, y = 0}
        end
    end
end

-- Set the current animation
function Creature:setAnimation(animName)
    -- For attack and hurt animations, we now trigger effects instead of changing animation
    if animName == "attack" then
        -- Since we don't have direct access to the battle system,
        -- we'll determine if this is a player creature in the battle
        -- when we're called from drawCreature in BattleSystem
        self:startAttackAnimation(false) -- Default to enemy until draw time
        return
    elseif animName == "hurt" then
        self:startFlashing()
        return
    end

    -- Only change animation if the requested one exists and has frames
    -- (This will usually only be "idle" now)
    if self.animations[animName] and
       self.animations[animName].frames and
       #self.animations[animName].frames > 0 then
        self.currentAnimation = animName
        self.animationFrame = 1
        self.animationTimer = 0
    elseif animName ~= self.currentAnimation then
        -- If changing to a non-existent animation, log this but don't crash
        print("Warning: Animation '" .. animName .. "' not found for creature " .. self.name .. ". Using fallback.")
        -- We'll keep the current animation if it's valid, or rely on the fallback in draw()
    end
end

return Creature