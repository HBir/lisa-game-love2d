-- World.lua - Main module that coordinates world functionality

local BlockRegistry = require("world.BlockRegistry")
local GridSystem = require("world.GridSystem")
local AutoTiler = require("world.AutoTiler")
local WorldRenderer = require("world.WorldRenderer")
local WorldGenerator = require("WorldGenerator")
local WorldSaveManager = require("WorldSaveManager")

local World = {}
World.__index = World


function World:new(width, height, tileSize)
    local self = setmetatable({}, World)

    self.width = width
    self.height = height
    self.tileSize = tileSize

    -- Initialize block registry
    self.blockRegistry = BlockRegistry()

    -- Initialize grid system
    self.gridSystem = GridSystem:new(width, height, self.blockRegistry)

    -- Initialize auto-tiler
    self.autoTiler = AutoTiler:new(self.gridSystem, self.blockRegistry)

    -- Initialize world renderer
    self.renderer = WorldRenderer:new(self.gridSystem, self.blockRegistry, self.autoTiler, tileSize)

    -- Initialize world generator
    self.generator = WorldGenerator:new(self.gridSystem, self.blockRegistry)

    -- Store reference to world in generator for saving player and NPC positions
    self.generator.world = self

    -- Initialize save manager
    self.saveManager = WorldSaveManager:new(self.gridSystem, self.generator)

    -- For backwards compatibility (to be removed eventually)
    self.foregroundGrid = self.gridSystem.foregroundGrid
    self.backgroundGrid = self.gridSystem.backgroundGrid
    self.grid = self.foregroundGrid
    -- self.blocks = self.blockRegistry.blocks
    -- self.blockQuads = self.blockRegistry.blockQuads
    -- self.spriteSheet = self.blockRegistry.spriteSheet
    -- self.tilesetSize = self.blockRegistry.tilesetSize

    -- Copy block type constants to the world object for external access
    -- This is for backwards compatibility and will be deprecated in the future
    -- Code should use self.blockRegistry.BLOCK_X constants directly
    for key, value in pairs(self.blockRegistry) do
        if type(key) == "string" and key:match("^BLOCK_") then
            self[key] = value
        end
    end

    return self
end

-- Generate the world terrain
function World:generate()
    self.generator:generate()
end

-- Helper functions that forward to the appropriate module

-- Get block at world coordinates
function World:getBlock(x, y, layer)
    return self.gridSystem:getBlock(x / self.tileSize, y / self.tileSize, layer)
end

-- Get block at grid coordinates
function World:getBlockAt(gridX, gridY, layer)
    return self.gridSystem:getBlockAt(gridX, gridY, layer)
end

-- Set block at grid coordinates
function World:setBlock(x, y, blockType)
    return self.gridSystem:setBlock(x, y, blockType)
end

-- Place block at world coordinates
function World:placeBlock(x, y, blockType)
    return self.gridSystem:placeBlock(x, y, blockType, self.tileSize)
end

-- Remove block at world coordinates
function World:removeBlock(x, y, targetLayer)
    return self.gridSystem:removeBlock(x, y, targetLayer, self.tileSize)
end

-- Check if a position is solid
function World:isSolid(x, y)
    return self.gridSystem:isSolid(x, y, self.tileSize)
end

-- Draw the world
function World:draw(camera)
    self.renderer:draw(camera)
end

-- Get auto-tile variant
function World:getAutoTileVariant(x, y, blockType, layer)
    return self.autoTiler:getAutoTileVariant(x, y, blockType, layer)
end

-- Save the world
function World:saveWorld(filename)
    return self.saveManager:saveWorld(filename)
end

-- Load the world
function World:loadWorld(filename)
    return self.saveManager:loadWorld(filename)
end

return World