-- WorldRenderer.lua - Handles rendering the world grid
local WorldRenderer = {}
WorldRenderer.__index = WorldRenderer

function WorldRenderer:new(gridSystem, blockRegistry, autoTiler, tileSize)
    local self = setmetatable({}, WorldRenderer)

    self.gridSystem = gridSystem
    self.blockRegistry = blockRegistry
    self.autoTiler = autoTiler
    self.tileSize = tileSize
    self.furnitureRegistry = gridSystem.furnitureRegistry

    -- Initialize furniture placement preview
    self.showFurniturePreview = false
    self.previewFurnitureType = nil
    self.previewX = 0
    self.previewY = 0
    self.canPlace = false

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

    -- Draw furniture layer
    self:drawFurniture(camera, startX, startY, endX, endY)

    -- Draw furniture placement preview if active
    if self.showFurniturePreview and self.previewFurnitureType then
        self:drawFurniturePreview()
    end

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
            -- local croppedImage = self.blockRegistry:getCroppedImage(blockType, blockVariant)

            -- -- Draw using sprite if available
            if quadToUse then
                -- Calculate scaling to match tile size
                local scale = 1


                -- Draw the sprite with proper scaling
                love.graphics.draw(
                    self.blockRegistry.spriteSheet,
                    quadToUse,
                    posX,
                    posY,
                    0,  -- rotation
                    scale,
                    scale
                )
                -- love.graphics.draw(croppedImage, quadToUse, posX, posY, 0, scale, scale)
            else
                print("No quad found for block type: " .. blockType .. " and variant: " .. blockVariant)

                -- Fallback to colored rectangle
                local block = self.blockRegistry:getBlock(blockType)
                local r, g, b, a = block.color[1], block.color[2], block.color[3], block.color[4] or 1
                love.graphics.setColor(r, g, b, a * alpha)
                love.graphics.rectangle("fill", posX, posY, self.tileSize, self.tileSize)

                -- Draw outline
                love.graphics.setColor(0, 0, 0, 0.3 * alpha)
                love.graphics.rectangle("line", posX, posY, self.tileSize, self.tileSize)
            end
            ::continue::
        end
    end
end

-- Draw furniture in the visible area
function WorldRenderer:drawFurniture(camera, startX, startY, endX, endY)
    -- Set default color
    love.graphics.setColor(1, 1, 1, 1)

    -- Track furniture origins we've already drawn to avoid duplicates
    local drawnFurniture = {}

    -- Check each cell in the visible area
    for y = startY, endY do
        for x = startX, endX do
            local furnitureData = self.gridSystem.furnitureGrid[y][x]
            if furnitureData then
                -- Get origin coordinates
                local originX = furnitureData.originX
                local originY = furnitureData.originY

                -- Create a key to track what we've drawn
                local key = originX .. "," .. originY

                -- Only draw each furniture item once
                if not drawnFurniture[key] then
                    drawnFurniture[key] = true

                    -- Get furniture type and details
                    local furnitureType = furnitureData.type
                    local furniture = self.furnitureRegistry:getFurniture(furnitureType)

                    if furniture then
                        -- Calculate position in pixels
                        local posX = (originX - 1) * self.tileSize
                        local posY = (originY - 1) * self.tileSize

                        -- Get furniture dimensions
                        local spriteW, spriteH = self.furnitureRegistry:getSpriteSize(furnitureType)
                        local gridW = furniture.width
                        local gridH = furniture.height

                        -- Get furniture state
                        local state = self.gridSystem:getFurnitureState(originX, originY)

                        -- Get the appropriate quad for this furniture's state
                        local quadToUse = self.furnitureRegistry:getQuad(furnitureType, state)

                        if quadToUse then
                            -- Calculate scale to fit exactly in the grid
                            local scaleX = (gridW * self.tileSize) / spriteW
                            local scaleY = (gridH * self.tileSize) / spriteH

                            -- Optional: Draw grid background (uncomment if you want it)
                            -- love.graphics.setColor(0.2, 0.2, 0.2, 0.3)
                            -- for gx = 0, gridW - 1 do
                            --     for gy = 0, gridH - 1 do
                            --         love.graphics.rectangle("fill",
                            --             posX + gx * self.tileSize,
                            --             posY + gy * self.tileSize,
                            --             self.tileSize, self.tileSize)
                            --     end
                            -- end

                            -- Draw the furniture sprite scaled to fit the grid
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.draw(
                                self.furnitureRegistry.spriteSheet,
                                quadToUse,
                                posX,
                                posY,
                                0,  -- rotation
                                scaleX,
                                scaleY
                            )
                        else
                            -- Fallback if quad not found: draw colored rectangle
                            local width = furniture.width * self.tileSize
                            local height = furniture.height * self.tileSize

                            -- Draw filled rectangle with furniture color
                            love.graphics.setColor(furniture.color)
                            love.graphics.rectangle("fill", posX, posY, width, height)

                            -- Draw outline
                            love.graphics.setColor(0, 0, 0, 0.5)
                            love.graphics.rectangle("line", posX, posY, width, height)

                            -- Add item name text
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.print(furniture.name, posX + 2, posY + 2)
                        end
                    end
                end
            end
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Set up the furniture preview
function WorldRenderer:setFurniturePreview(furnitureType, x, y, canPlace)
    self.showFurniturePreview = true
    self.previewFurnitureType = furnitureType
    self.previewX = x
    self.previewY = y
    self.canPlace = canPlace
end

-- Hide the furniture preview
function WorldRenderer:hideFurniturePreview()
    self.showFurniturePreview = false
end

-- Draw the furniture placement preview
function WorldRenderer:drawFurniturePreview()
    if not self.previewFurnitureType then return end

    -- Get furniture details
    local furniture = self.furnitureRegistry:getFurniture(self.previewFurnitureType)
    if not furniture then return end

    -- Get grid coordinates
    local gridX = math.floor(self.previewX / self.tileSize) + 1
    local gridY = math.floor(self.previewY / self.tileSize) + 1

    -- Calculate pixel position
    local posX = (gridX - 1) * self.tileSize
    local posY = (gridY - 1) * self.tileSize

    -- Get dimensions
    local width = furniture.width * self.tileSize
    local height = furniture.height * self.tileSize

    -- Set alpha based on placement validity
    local alpha = self.canPlace and 0.7 or 0.4

    -- Get the quad for default state
    local state = furniture.defaultState
    local quadToUse = self.furnitureRegistry:getQuad(self.previewFurnitureType, state)

    if quadToUse then
        -- Get furniture dimensions for scaling
        local spriteW, spriteH = self.furnitureRegistry:getSpriteSize(self.previewFurnitureType)
        local gridW = furniture.width
        local gridH = furniture.height

        -- Calculate scale to fit exactly in the grid
        local scaleX = (gridW * self.tileSize) / spriteW
        local scaleY = (gridH * self.tileSize) / spriteH

        -- Draw grid to indicate placement area
        love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
        for gx = 0, gridW - 1 do
            for gy = 0, gridH - 1 do
                love.graphics.rectangle("fill",
                    posX + gx * self.tileSize,
                    posY + gy * self.tileSize,
                    self.tileSize, self.tileSize)
            end
        end

        -- Tint green if can place, red if cannot
        if self.canPlace then
            love.graphics.setColor(0.7, 1, 0.7, alpha)
        else
            love.graphics.setColor(1, 0.7, 0.7, alpha)
        end

        -- Draw the furniture sprite with transparency
        love.graphics.draw(
            self.furnitureRegistry.spriteSheet,
            quadToUse,
            posX,
            posY,
            0,  -- rotation
            scaleX,
            scaleY
        )
    else
        -- Fallback: draw colored rectangle
        if self.canPlace then
            love.graphics.setColor(0, 1, 0, alpha)
        else
            love.graphics.setColor(1, 0, 0, alpha)
        end

        love.graphics.rectangle("fill", posX, posY, width, height)

        -- Draw outline
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("line", posX, posY, width, height)

        -- Draw furniture name
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(furniture.name, posX + 2, posY + 2)
    end

    -- Draw grid outline to show exact placement area
    love.graphics.setColor(1, 1, 1, 0.5)
    for y = 0, furniture.height - 1 do
        for x = 0, furniture.width - 1 do
            love.graphics.rectangle(
                "line",
                posX + (x * self.tileSize),
                posY + (y * self.tileSize),
                self.tileSize,
                self.tileSize
            )
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return WorldRenderer