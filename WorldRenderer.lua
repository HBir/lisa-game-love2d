-- WorldRenderer.lua - Handles rendering the world grid
local WorldRenderer = {}
WorldRenderer.__index = WorldRenderer

function WorldRenderer:new(gridSystem, blockRegistry, autoTiler, tileSize)
    local self = setmetatable({}, WorldRenderer)

    self.gridSystem = gridSystem
    self.blockRegistry = blockRegistry
    self.autoTiler = autoTiler
    self.tileSize = tileSize

    return self
end

function WorldRenderer:draw(camera)
    -- Get visible area bounds in tiles
    local x1, y1, x2, y2 = camera:getBounds()

    -- Convert to grid indices
    local startX = math.max(1, math.floor(x1 / self.tileSize) + 1)
    local startY = math.max(1, math.floor(y1 / self.tileSize) + 1)
    local endX = math.min(self.gridSystem.width, math.floor(x2 / self.tileSize) + 1)
    local endY = math.min(self.gridSystem.height, math.floor(y2 / self.tileSize) + 1)

    -- Draw background layer first
    self:drawLayer(camera, startX, startY, endX, endY, "background")

    -- Then draw foreground layer on top
    self:drawLayer(camera, startX, startY, endX, endY, "foreground")

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Helper method to draw a specific layer
function WorldRenderer:drawLayer(camera, startX, startY, endX, endY, layer)
    local grid = layer == "background" and self.gridSystem.backgroundGrid or self.gridSystem.foregroundGrid
    local alpha = layer == "background" and 0.9 or 1.0 -- Slightly less opacity for background

    -- Draw visible blocks in this layer
    for y = startY, endY do
        local posY = (y - 1) * self.tileSize
        for x = startX, endX do
            local blockType = grid[y][x]
            -- Skip air blocks
            if blockType == self.blockRegistry.BLOCK_AIR then
                goto continue
            end
                -- Calculate position
            local posX = (x - 1) * self.tileSize

            -- Set color for the block (used for tinting or if no sprite)
            love.graphics.setColor(1, 1, 1, alpha)
            -- Draw block number on screen

            -- -- Get the variant of the block to use based on auto-tiling
            local blockVariant = self.autoTiler:getAutoTileVariant(x, y, blockType, layer)
            -- local quadToUse = self.blockRegistry.blockQuads[blockVariant]
            local quadToUse = self.blockRegistry:getQuad(blockType, blockVariant)

            -- -- Draw using sprite if available
            if quadToUse then
                -- Calculate scaling to match tile size
                local scaleX = 1
                local scaleY = 1


                -- Draw the sprite with proper scaling
                love.graphics.draw(
                    self.blockRegistry.spriteSheet,
                    quadToUse,
                    posX,
                    posY,
                    0,  -- rotation
                    scaleX,
                    scaleY
                )
            else
                print("No quad found for block type: " .. blockType .. " and variant: " .. blockVariant)

                -- Fallback to colored rectangle
                local block = self.blockRegistry:getBlock(blockType)
                local r, g, b, a = block.color[1], block.color[2], block.color[3], block.color[4] or 1
                love.graphics.setColor(r, g, b, a * alpha)
                love.graphics.rectangle("fill", pixelX, pixelY, self.tileSize, self.tileSize)

                -- Draw outline
                love.graphics.setColor(0, 0, 0, 0.3 * alpha)
                love.graphics.rectangle("line", pixelX, pixelY, self.tileSize, self.tileSize)
            end
            ::continue::
        end
    end
end

return WorldRenderer