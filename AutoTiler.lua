-- AutoTiler.lua - Handles block auto-tiling logic
local AutoTiler = {}
AutoTiler.__index = AutoTiler

function AutoTiler:new(gridSystem, blockRegistry)
    local self = setmetatable({}, AutoTiler)

    self.gridSystem = gridSystem
    self.blockRegistry = blockRegistry

    -- Define all possible variants
    self.variants = {
        "_TOP", "_BOTTOM", "_LEFT", "_RIGHT",
        "_TOP_LEFT", "_TOP_RIGHT", "_BOTTOM_LEFT", "_BOTTOM_RIGHT",
        "_TOP_BOTTOM", "_LEFT_RIGHT", "_MIDDLE"
    }

    return self
end

-- Determine the appropriate tile variant based on surroundings
function AutoTiler:getAutoTileVariant(x, y, blockType, layer)
    -- If it's air, just return air
    if blockType == self.blockRegistry.BLOCK_AIR then
        return tostring(blockType)
    end

    -- For all blocks, check surrounding blocks of the same type
    local function isSameBlock(checkX, checkY)
        local block = self.gridSystem:getBlockAt(checkX, checkY, layer)

        -- Special case for leaves - both tree and wood connect with leaves
        if blockType == self.blockRegistry.BLOCK_LEAVES then
            return block == self.blockRegistry.BLOCK_LEAVES
                or block == self.blockRegistry.BLOCK_TREE
                or block == self.blockRegistry.BLOCK_WOOD
        end

        return block == blockType
    end

    local hasBlockAbove = isSameBlock(x, y-1)
    local hasBlockBelow = isSameBlock(x, y+1)
    local hasBlockLeft = isSameBlock(x-1, y)
    local hasBlockRight = isSameBlock(x+1, y)

    -- Determine the variant based on neighbors
    local variant

    -- Check for all the different possible configurations
    if hasBlockAbove and hasBlockBelow and hasBlockLeft and hasBlockRight then
        -- Block surrounded on all sides - use middle sprite
        variant = "_MIDDLE"
    elseif not hasBlockAbove and hasBlockBelow and not hasBlockLeft and hasBlockRight then
        -- Top-left corner
        variant = "_TOP_LEFT"
    elseif not hasBlockAbove and hasBlockBelow and hasBlockLeft and not hasBlockRight then
        -- Top-right corner
        variant = "_TOP_RIGHT"
    elseif hasBlockAbove and not hasBlockBelow and not hasBlockLeft and hasBlockRight then
        -- Bottom-left corner
        variant = "_BOTTOM_LEFT"
    elseif hasBlockAbove and not hasBlockBelow and hasBlockLeft and not hasBlockRight then
        -- Bottom-right corner
        variant = "_BOTTOM_RIGHT"
    elseif hasBlockAbove and hasBlockBelow and not hasBlockLeft and not hasBlockRight then
        -- Left-right edge
        variant = "_LEFT_RIGHT"
    elseif not hasBlockAbove and not hasBlockBelow and hasBlockLeft and hasBlockRight then
        -- Top-bottom edge
        variant = "_TOP_BOTTOM"
    elseif hasBlockAbove and hasBlockBelow and not hasBlockLeft and hasBlockRight then
        -- Left edge
        variant = "_LEFT"
    elseif hasBlockAbove and hasBlockBelow and hasBlockLeft and not hasBlockRight then
        -- Right edge
        variant = "_RIGHT"
    elseif hasBlockAbove and not hasBlockBelow and hasBlockLeft and hasBlockRight then
        -- Bottom edge
        variant = "_BOTTOM"
    elseif not hasBlockAbove and hasBlockBelow and hasBlockLeft and hasBlockRight then
        -- Top edge
        variant = "_TOP"
    else
        -- Default
        variant = "_TOP"
    end

    -- Check if the variant exists in our registry
    local variantKey = blockType .. variant
    if self.blockRegistry.blockQuads[variantKey] then
        return variantKey
    else
        -- Fall back to default
        return tostring(blockType)
    end
end

return AutoTiler