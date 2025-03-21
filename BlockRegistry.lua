-- BlockRegistry.lua - Handles block type definitions and sprite loading
local BlockRegistry = {}
BlockRegistry.__index = BlockRegistry

-- Block type constants
BlockRegistry.BLOCK_AIR = 0
BlockRegistry.BLOCK_DIRT = 1
BlockRegistry.BLOCK_STONE = 2
BlockRegistry.BLOCK_TREE = 3
BlockRegistry.BLOCK_LEAVES = 4
BlockRegistry.BLOCK_WOOD = 5
BlockRegistry.BLOCK_WOOD_BACKGROUND = 6
BlockRegistry.REMOVE_BACKGROUND = 7
BlockRegistry.BLOCK_STONE_BACKGROUND = 8

function BlockRegistry:new()
    local self = setmetatable({}, BlockRegistry)

    -- Load sprite sheet
    self.spriteSheet = love.graphics.newImage("assets/Tiles/Assets/Assets.png")
    self.tilesetSize = 16 -- Size of each tile in the sprite sheet

    -- Initialize sprite mapping table
    self.sprites = self:initializeSpriteMapping()

    -- Initialize block definitions
    self.blocks = self:initializeBlockDefinitions()

    -- Create quads for each block type plus variants
    self.blockQuads = self:createQuads()

    return self
end

function BlockRegistry:initializeSpriteMapping()
    local sprites = {}

    -- Basic blocks
    sprites[self.BLOCK_AIR] = { x = 0, y = 0 }

    -- Dirt block and variants
    sprites[self.BLOCK_DIRT] = { x = 3, y = 0 }
    sprites[self.BLOCK_DIRT .. "_TOP"] = { x = 3, y = 0 }
    sprites[self.BLOCK_DIRT .. "_TOP_LEFT"] = { x = 2, y = 0 }
    sprites[self.BLOCK_DIRT .. "_LEFT"] = { x = 1, y = 2 }
    sprites[self.BLOCK_DIRT .. "_TOP_RIGHT"] = { x = 5, y = 1 }
    sprites[self.BLOCK_DIRT .. "_RIGHT"] = { x = 5, y = 2 }
    sprites[self.BLOCK_DIRT .. "_MIDDLE"] = { x = 3, y = 1 }
    sprites[self.BLOCK_DIRT .. "_BOTTOM_LEFT"] = { x = 3, y = 1 }
    sprites[self.BLOCK_DIRT .. "_BOTTOM_RIGHT"] = { x = 3, y = 1 }
    sprites[self.BLOCK_DIRT .. "_BOTTOM"] = { x = 3, y = 1 }

    -- Tree block and variants
    sprites[self.BLOCK_TREE] = { x = 9, y = 18 }
    sprites[self.BLOCK_TREE .. "_TOP_LEFT"] = { x = 9, y = 17 }
    sprites[self.BLOCK_TREE .. "_LEFT"] = { x = 9, y = 17 }
    sprites[self.BLOCK_TREE .. "_BOTTOM_LEFT"] = { x = 9, y = 17 }
    sprites[self.BLOCK_TREE .. "_RIGHT"] = { x = 10, y = 17 }
    sprites[self.BLOCK_TREE .. "_BOTTOM_RIGHT"] = { x = 10, y = 17 }
    sprites[self.BLOCK_TREE .. "_TOP_RIGHT"] = { x = 10, y = 17 }

    -- Wood blocks
    sprites[self.BLOCK_WOOD] = { x = 8, y = 8 }
    sprites[self.BLOCK_WOOD_BACKGROUND] = { x = 8, y = 13 }

    -- Leaf blocks and variants
    sprites[self.BLOCK_LEAVES] = { x = 3, y = 15 }
    sprites[self.BLOCK_LEAVES .. "_MIDDLE"] = { x = 2, y = 17 }
    sprites[self.BLOCK_LEAVES .. "_TOP"] = { x = 3, y = 15 }
    sprites[self.BLOCK_LEAVES .. "_BOTTOM"] = { x = 3, y = 19 }
    sprites[self.BLOCK_LEAVES .. "_LEFT"] = { x = 1, y = 17 }
    sprites[self.BLOCK_LEAVES .. "_RIGHT"] = { x = 5, y = 17 }
    sprites[self.BLOCK_LEAVES .. "_TOP_LEFT"] = { x = 1, y = 16 }
    sprites[self.BLOCK_LEAVES .. "_TOP_RIGHT"] = { x = 4, y = 15 }
    sprites[self.BLOCK_LEAVES .. "_BOTTOM_LEFT"] = { x = 1, y = 18 }
    sprites[self.BLOCK_LEAVES .. "_BOTTOM_RIGHT"] = { x = 4, y = 19 }
    sprites[self.BLOCK_LEAVES .. "_TOP_BOTTOM"] = { x = 4, y = 17 }
    sprites[self.BLOCK_LEAVES .. "_LEFT_RIGHT"] = { x = 2, y = 19 }

    -- Stone blocks and variants
    sprites[self.BLOCK_STONE] = { x = 3, y = 5 }
    sprites[self.BLOCK_STONE .. "_TOP"] = { x = 3, y = 5 }
    sprites[self.BLOCK_STONE .. "_MIDDLE"] = { x = 3, y = 8 }
    sprites[self.BLOCK_STONE .. "_LEFT"] = { x = 1, y = 7 }
    sprites[self.BLOCK_STONE .. "_RIGHT"] = { x = 4, y = 9 }
    sprites[self.BLOCK_STONE .. "_TOP_LEFT"] = { x = 1, y = 6 }
    sprites[self.BLOCK_STONE .. "_TOP_RIGHT"] = { x = 5, y = 6 }
    sprites[self.BLOCK_STONE .. "_TOP_BOTTOM"] = { x = 5, y = 9 }
    sprites[self.BLOCK_STONE .. "_BOTTOM"] = { x = 3, y = 9 }
    sprites[self.BLOCK_STONE .. "_BOTTOM_LEFT"] = { x = 2, y = 9 }
    sprites[self.BLOCK_STONE .. "_BOTTOM_RIGHT"] = { x = 4, y = 9 }
    sprites[self.BLOCK_STONE .. "_LEFT_RIGHT"] = { x = 3, y = 11 }

    -- Stone background blocks and variants
    sprites[self.BLOCK_STONE_BACKGROUND] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_TOP"] = { x = 13, y = 12 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_TOP_LEFT"] = { x = 13, y = 12 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_TOP_RIGHT"] = { x = 13, y = 12 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_TOP_BOTTOM"] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_BOTTOM"] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_BOTTOM_LEFT"] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_BOTTOM_RIGHT"] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_LEFT_RIGHT"] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_MIDDLE"] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_LEFT"] = { x = 13, y = 13 }
    sprites[self.BLOCK_STONE_BACKGROUND .. "_RIGHT"] = { x = 13, y = 13 }

    return sprites
end

function BlockRegistry:initializeBlockDefinitions()
    local blocks = {}

    blocks[self.BLOCK_AIR] = {
        name = "Air",
        color = {0, 0, 0, 0},
        solid = false,
        sprite = nil
    }

    blocks[self.BLOCK_DIRT] = {
        name = "Dirt",
        color = {0.6, 0.4, 0.2, 1},
        solid = true,
        sprite = self.sprites[self.BLOCK_DIRT]
    }

    blocks[self.BLOCK_STONE] = {
        name = "Stone",
        color = {0.5, 0.5, 0.5, 1},
        solid = true,
        sprite = self.sprites[self.BLOCK_STONE]
    }

    blocks[self.BLOCK_TREE] = {
        name = "Tree",
        color = {0.6, 0.3, 0.1, 1},
        solid = false,
        sprite = self.sprites[self.BLOCK_TREE]
    }

    blocks[self.BLOCK_WOOD] = {
        name = "Wood",
        color = {0.8, 0.6, 0.4, 1},
        solid = true,
        sprite = self.sprites[self.BLOCK_WOOD]
    }

    blocks[self.BLOCK_WOOD_BACKGROUND] = {
        name = "Wood Background",
        color = {0.7, 0.5, 0.3, 0.8},
        solid = false,
        sprite = self.sprites[self.BLOCK_WOOD_BACKGROUND]
    }

    blocks[self.BLOCK_LEAVES] = {
        name = "Leaves",
        color = {0.1, 0.6, 0.1, 1},
        solid = false,
        sprite = self.sprites[self.BLOCK_LEAVES]
    }

    blocks[self.REMOVE_BACKGROUND] = {
        name = "Remove Background",
        color = {0.8, 0.8, 1, 0.3}, -- Light blue tint to represent "background eraser"
        solid = false,
        isBackgroundEraser = true,
        sprite = nil
    }

    blocks[self.BLOCK_STONE_BACKGROUND] = {
        name = "Stone Background",
        color = {0.5, 0.5, 0.5, 0.8},
        solid = false,
        sprite = self.sprites[self.BLOCK_STONE_BACKGROUND]
    }

    return blocks
end

function BlockRegistry:createQuads()
    local quads = {}

    -- Create quads for each block type
    for blockType, block in pairs(self.blocks) do
        if block.sprite then
            quads[blockType] = love.graphics.newQuad(
                block.sprite.x * self.tilesetSize,
                block.sprite.y * self.tilesetSize,
                self.tilesetSize,
                self.tilesetSize,
                self.spriteSheet:getDimensions()
            )
        end
    end

    -- List of all possible variants to check for each block type
    local variants = {
        "_TOP", "_BOTTOM", "_LEFT", "_RIGHT",
        "_TOP_LEFT", "_TOP_RIGHT", "_BOTTOM_LEFT", "_BOTTOM_RIGHT",
        "_TOP_BOTTOM", "_LEFT_RIGHT", "_MIDDLE"
    }

    -- Add quads for all variants of all block types
    for blockType, _ in pairs(self.blocks) do
        if blockType ~= self.BLOCK_AIR then
            for _, variant in ipairs(variants) do
                local blockVariant = blockType .. variant
                if self.sprites[blockVariant] then
                    quads[blockVariant] = love.graphics.newQuad(
                        self.sprites[blockVariant].x * self.tilesetSize,
                        self.sprites[blockVariant].y * self.tilesetSize,
                        self.tilesetSize,
                        self.tilesetSize,
                        self.spriteSheet:getDimensions()
                    )
                end
            end
        end
    end

    return quads
end

function BlockRegistry:getQuad(blockType, variant)
    local key = variant and (blockType .. variant) or blockType
    return self.blockQuads[key]
end

function BlockRegistry:getBlock(blockType)
    return self.blocks[blockType]
end

function BlockRegistry:isSolid(blockType)
    local block = self.blocks[blockType]
    return block and block.solid
end

-- Export the constants directly on the module for convenience
return function()
    local registry = BlockRegistry:new()

    -- Copy constants to the registry instance
    for k, v in pairs(BlockRegistry) do
        if type(k) == "string" and k:match("^BLOCK_") then
            registry[k] = v
        end
    end

    return registry
end