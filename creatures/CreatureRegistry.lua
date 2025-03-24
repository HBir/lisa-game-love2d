-- CreatureRegistry class for managing all creature types
local Creature = require("creatures.Creature")
local Moves = require("creatures.Move")

local CreatureRegistry = {}
CreatureRegistry.__index = CreatureRegistry

function CreatureRegistry:new()
    local self = setmetatable({}, self)

    -- Initialize registry
    self.creatureTypes = {}
    self.spriteSheets = {}

    -- Register default creatures
    self:registerDefaultCreatures()

    return self
end

-- Register a new creature type
function CreatureRegistry:registerCreature(id, name, baseStats, defaultMoves, spriteInfo)
    self.creatureTypes[id] = {
        name = name,
        baseStats = baseStats,
        defaultMoves = defaultMoves,
        spriteInfo = spriteInfo
    }
end

-- Create a new instance of a creature by id
function CreatureRegistry:createCreature(id, level, world, x, y, isPlayerOwned)
    print("Creating creature: " .. id )
    local creatureType = self.creatureTypes[id]
    if not creatureType then
        return nil, "Creature type not found: " .. id
    end

    -- Create the new creature instance
    local level = level or math.random(1, 5) -- Default random level 1-5
    local creature = Creature:new(
        creatureType.name,
        level,
        creatureType.baseStats.hp,
        creatureType.baseStats.attack,
        creatureType.baseStats.speed
    )

    -- Add default moves
    for _, moveInfo in ipairs(creatureType.defaultMoves) do
        local move = Moves.MoveList[moveInfo.name]()
        creature:learnMove(move)
    end

    -- Load default chicken sprite sheet as fallback
    local defaultSpriteSheet = "assets/Overworld/chicken.png"
    if not self.spriteSheets[defaultSpriteSheet] then
        self.spriteSheets[defaultSpriteSheet] = love.graphics.newImage(defaultSpriteSheet)
    end

    -- Assign default chicken sheet as a fallback
    creature.spriteSheet = self.spriteSheets[defaultSpriteSheet]

    -- Default chicken animation frames as fallback (only idle animation needed now)
    local defaultAnimations = {
        idle = {
            frames = {
                { x = 7, y = 16, width = 17, height = 16 },
                { x = 39, y = 16, width = 17, height = 16 },
                { x = 71, y = 16, width = 17, height = 16 },
                { x = 103, y = 16, width = 17, height = 16 }
            },
            frameTime = 0.2
        }
    }

    -- Initialize with default animations
    creature.animations = defaultAnimations

    -- Override with custom sprite if available
    if creatureType.spriteInfo and creatureType.spriteInfo.sheet then
        -- Load custom sprite sheet if not already loaded
        if not self.spriteSheets[creatureType.spriteInfo.sheet] then
            self.spriteSheets[creatureType.spriteInfo.sheet] = love.graphics.newImage(creatureType.spriteInfo.sheet)
        end

        -- Replace default with custom sprite sheet
        creature.spriteSheet = self.spriteSheets[creatureType.spriteInfo.sheet]
    end

    -- Override with custom animations if available (just idle animation)
    if creatureType.animations and creatureType.animations.idle then
        if creatureType.animations.idle.frames and #creatureType.animations.idle.frames > 0 then
            creature.animations.idle = creatureType.animations.idle
        else
            print("Warning: Idle animation for creature " .. id .. " has missing frames, using default.")
        end
    end

    -- Initialize animation state
    creature.currentAnimation = "idle"
    creature.animationFrame = 1
    creature.animationTimer = 0

    -- Set animation frame time if provided
    if creature.animations.idle and creature.animations.idle.frameTime then
        creature.animationFrameTime = creature.animations.idle.frameTime
    end

    -- Set creature ID for reference
    creature.id = id

    -- Create overworld representation if world is provided
    if world and x and y then
        -- Create an overworld creature representation
        local OverworldCreature = require("npc.OverworldCreature")

        local overworldEntity = OverworldCreature:new(world, x, y, id, level)

        -- Link the battle creature and overworld entity
        creature.overworldEntity = overworldEntity
        overworldEntity.battleCreature = creature

        -- Set the player-owned flag if provided
        if isPlayerOwned then
            overworldEntity.isPlayerOwned = true
            overworldEntity.followPlayer = true
            overworldEntity.behavior = "follow" -- Override default wander behavior
        end
    end

    return creature
end

-- Register default creature types
function CreatureRegistry:registerDefaultCreatures()
    -- Chicken (based on existing NPC)
    self:registerCreature(
        "chicken",
        "Chicken",
        { hp = 20, attack = 4, speed = 7 },
        {
            { name = "Scratch" },
            { name = "Growl" }
        },
        {
            sheet = "assets/Overworld/chicken.png",
            animations = {
                idle = {
                    sheet = "assets/Overworld/chicken.png",
                    frames = {
                        { x = 0, y = 0, width = 64, height = 64 },
                        { x = 64, y = 0, width = 64, height = 64 },

                    },
                    frameTime = 0.2
                }, walk = {
                    sheet = "assets/Overworld/chicken.png",
                    frames = {
                        { x = 64, y = 0, width = 64, height = 64 },
                        { x = 64, y = 64, width = 64, height = 64 },
                        { x = 64, y = 128, width = 64, height = 64 },
                        { x = 64, y = 192, width = 64, height = 64 },
                        { x = 64, y = 256, width = 64, height = 64 },
                        { x = 64, y = 320, width = 64, height = 64 },
                        { x = 64, y = 384, width = 64, height = 64 },
                    },
                    frameTime = 0.2
                }
            },
            spriteInfo = {
                sheet = "assets/Overworld/chicken.png"
            }
        }
    )

    -- Add more creatures here
    self:registerCreature(
        "lilly",
        "Lilly",
        { hp = 18, attack = 3, speed = 9 },
        {
            { name = "Tackle" },
            { name = "Growl" }
        },
        {
            sheet = "assets/Monsters/Lilly.png",
            animations = {
                idle = {
                    sheet = "assets/Monsters/Lilly.png",
                    frames = {
                        { x = 0, y = 0, width = 64, height = 64 },
                        { x = 64, y = 0, width = 64, height = 64 },
                        { x = 128, y = 0, width = 64, height = 64 },
                    },
                    frameTime = 0.2
                }
            },
            spriteInfo = {
                sheet = "assets/Monsters/Lilly.png" -- Will fallback to chicken sprite
            }
        }
    )

end

-- Get a list of all registered creature types
function CreatureRegistry:getCreatureTypes()
    local types = {}
    for id, _ in pairs(self.creatureTypes) do
        table.insert(types, id)
    end
    return types
end

-- Get creature type info by id
function CreatureRegistry:getCreatureTypeInfo(id)
    return self.creatureTypes[id]
end

return CreatureRegistry