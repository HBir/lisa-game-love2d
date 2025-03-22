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
BlockRegistry.BLOCK_STONE_BACKGROUND = 7
BlockRegistry.REMOVE_BACKGROUND = 8

function BlockRegistry:new()
    local self = setmetatable({}, BlockRegistry)

    -- Load sprite sheet
    self.spriteSheet = love.graphics.newImage("assets/Tiles/Assets/Assets-sheet.png")
    -- self.spriteSheet:setFilter("nearest", "nearest")
    self.tilesetSize = 16 -- Size of each tile in the sprite sheet

    -- Initialize sprite mapping table
    self.sprites = self:initializeSpriteMapping()

    -- Initialize block definitions
    self.blocks = self:initializeBlockDefinitions()

    -- Create quads for each block type plus variants
    self.blockQuads, self.croppedImages = self:createQuads()

    return self
end

-- This will returns an array
function BlockRegistry:createBlockWithVariants(blockType, variants)
    local sprites = {}

    -- sprites[blockType] = { x = variants[1][2][1], y = variants[1][2][2] }
    sprites[blockType .. "_TOP_LEFT"] = { x = variants[1][1][1], y = variants[1][1][2] }
    sprites[blockType .. "_TOP"] = { x = variants[1][2][1], y = variants[1][2][2] }
    sprites[blockType .. "_TOP_RIGHT"] = { x = variants[1][3][1], y = variants[1][3][2] }
    sprites[blockType .. "_LEFT"] = { x = variants[2][1][1], y = variants[2][1][2] }
    sprites[blockType .. "_MIDDLE"] = { x = variants[2][2][1], y = variants[2][2][2] }
    sprites[blockType .. "_RIGHT"] = { x = variants[2][3][1], y = variants[2][3][2] }
    sprites[blockType .. "_BOTTOM_LEFT"] = { x = variants[3][1][1], y = variants[3][1][2] }
    sprites[blockType .. "_BOTTOM"] = { x = variants[3][2][1], y = variants[3][2][2] }
    sprites[blockType .. "_BOTTOM_RIGHT"] = { x = variants[3][3][1], y = variants[3][3][2] }

    sprites[blockType .. "_LEFT_RIGHT"] = { x = variants[2][1][1], y = variants[2][3][2] }
    sprites[blockType .. "_TOP_BOTTOM"] = { x = variants[1][2][1], y = variants[1][2][2] }


    return sprites
end

function BlockRegistry:initializeSpriteMapping()
    local sprites = {}

    -- Basic blocks
    sprites[self.BLOCK_AIR] = { x = 0, y = 0 }

    local blockTypes = {
        self:createBlockWithVariants(self.BLOCK_DIRT,
            {{{1,0},{2,0},{5,1}},
            {{12,1},{3,1},{5,2}},
            {{3,1},{3,1},{3,1}}}
        ),
        self:createBlockWithVariants(self.BLOCK_TREE,
            {{{3,13},{3,13},{4,13}},
            {{3,13},{3,13},{4,13}},
            {{3,13},{3,13},{4,13}}}
        ),
        self:createBlockWithVariants(self.BLOCK_WOOD,
            {{{5,8},{5,8},{5,8}},
            {{5,8},{5,8},{5,8}},
            {{5,8},{5,8},{5,8}}}
        ),
        self:createBlockWithVariants(self.BLOCK_LEAVES,
            {{{11,11},{12,11},{13,11}},
            {{15,12},{10,12},{0,13}},
            {{7,13},{13,13},{10,13}}}
        ),
        self:createBlockWithVariants(self.BLOCK_STONE,
            {{{1,5},{2,5},{3,5}},
            {{2,7},{3,11},{3,7}},
            {{0,8},{13,8},{3,8}}}
        ),
        self:createBlockWithVariants(self.BLOCK_STONE_BACKGROUND,
            {{{8,10},{9,10},{10,10}},
            {{1,11},{1,11},{1,11}},
            {{1,11},{1,11},{1,11}}}
        ),
        self:createBlockWithVariants(self.BLOCK_WOOD_BACKGROUND,
            {{{15,10},{15,10},{15,10}},
            {{15,10},{15,10},{15,10}},
            {{15,10},{15,10},{15,10}}}
        ),
        self:createBlockWithVariants(self.REMOVE_BACKGROUND,
            {{{12,14},{12,14},{12,14}},
            {{12,14},{12,14},{12,14}},
            {{12,14},{12,14},{12,14}}}
        ),
    }

    for _, blockType in pairs(blockTypes) do
        for k, v in pairs(blockType) do
            print(k, v)
            sprites[k] = v
        end
    end

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
    local croppedImages = {}

    -- List of all possible variants to check for each block type
    local variants = {
        "_TOP", "_BOTTOM", "_LEFT", "_RIGHT",
        "_TOP_LEFT", "_TOP_RIGHT", "_BOTTOM_LEFT", "_BOTTOM_RIGHT",
        "_TOP_BOTTOM", "_LEFT_RIGHT", "_MIDDLE"
    }

    local spacing = 1

    -- Add quads for all variants of all block types
    for blockType, _ in pairs(self.blocks) do
        if blockType == self.BLOCK_AIR then
            goto continue
        end

        for _, variant in ipairs(variants) do
            local blockVariant = blockType .. variant
                if self.sprites[blockVariant] then
                    local x = self.sprites[blockVariant].x * (self.tilesetSize + spacing)
                    local y = self.sprites[blockVariant].y * (self.tilesetSize + spacing)
                    local w = self.tilesetSize
                    local h = self.tilesetSize
                    local tilesetW, tilesetH = self.spriteSheet:getWidth(), self.spriteSheet:getHeight()

                    quads[blockVariant] = love.graphics.newQuad(x,y,w,h,tilesetW, tilesetH)
            end
        end

        ::continue::
    end

    return quads, croppedImages
end

function BlockRegistry:getQuad(blockType, variant)
    local key = variant and variant or blockType
    return self.blockQuads[key]
end

function BlockRegistry:getCroppedImage(blockType, variant)
    local key = variant and variant or blockType
    return self.croppedImages[key]
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