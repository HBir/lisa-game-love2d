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
function CreatureRegistry:createCreature(id, level)
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

    -- Set sprite information
    if creatureType.spriteInfo and creatureType.spriteInfo.sheet then
        -- Load sprite sheet if not already loaded
        if not self.spriteSheets[creatureType.spriteInfo.sheet] then
            self.spriteSheets[creatureType.spriteInfo.sheet] = love.graphics.newImage(creatureType.spriteInfo.sheet)
        end

        creature.spriteSheet = self.spriteSheets[creatureType.spriteInfo.sheet]
        creature.animations = creatureType.spriteInfo.animations
    end

    -- Set creature ID for reference
    creature.id = id

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
                    frames = { { x = 0, y = 0, width = 16, height = 16 } },
                    frameTime = 0.2
                },
                attack = {
                    frames = {
                        { x = 16, y = 0, width = 16, height = 16 },
                        { x = 32, y = 0, width = 16, height = 16 }
                    },
                    frameTime = 0.1
                },
                hurt = {
                    frames = { { x = 48, y = 0, width = 16, height = 16 } },
                    frameTime = 0.2
                }
            }
        }
    )

    -- Add more creatures here
    self:registerCreature(
        "bunny",
        "Bunny",
        { hp = 18, attack = 3, speed = 9 },
        {
            { name = "Tackle" },
            { name = "Growl" }
        },
        {
            sheet = "assets/Overworld/chicken.png", -- Placeholder path, you'll need the actual sprite
            animations = {
                idle = {
                    frames = { { x = 0, y = 0, width = 16, height = 16 } },
                    frameTime = 0.2
                },
                attack = {
                    frames = {
                        { x = 16, y = 0, width = 16, height = 16 },
                        { x = 32, y = 0, width = 16, height = 16 }
                    },
                    frameTime = 0.1
                },
                hurt = {
                    frames = { { x = 48, y = 0, width = 16, height = 16 } },
                    frameTime = 0.2
                }
            }
        }
    )

    self:registerCreature(
        "fox",
        "Fox",
        { hp = 25, attack = 6, speed = 6 },
        {
            { name = "Scratch" },
            { name = "Tackle" }
        },
        {
            sheet = "assets/Overworld/chicken.png", -- Placeholder path, you'll need the actual sprite
            animations = {
                idle = {
                    frames = { { x = 0, y = 0, width = 16, height = 16 } },
                    frameTime = 0.2
                },
                attack = {
                    frames = {
                        { x = 16, y = 0, width = 16, height = 16 },
                        { x = 32, y = 0, width = 16, height = 16 }
                    },
                    frameTime = 0.1
                },
                hurt = {
                    frames = { { x = 48, y = 0, width = 16, height = 16 } },
                    frameTime = 0.2
                }
            }
        }
    )

    -- You can add more creatures here
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