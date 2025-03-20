-- Game class that manages the overall game state
local Camera = require("camera")
local World = require("world")
local Player = require("player")

local Game = {}
Game.__index = Game

function Game:new()
    local self = setmetatable({}, Game)

    -- Game settings
    self.title = "Princess Builder"
    self.width = 800
    self.height = 600

    -- Interaction state
    self.mouseX = 0
    self.mouseY = 0
    self.isPlacingBlock = false
    self.isRemovingBlock = false

    return self
end

function Game:load()
    -- Set window properties
    love.window.setTitle(self.title)
    love.window.setMode(self.width, self.height, {
        resizable = true,
        vsync = true,
        minwidth = 400,
        minheight = 300
    })

    -- Load background image
    self.backgroundImage = love.graphics.newImage("assets/Tiles/Assets/Background_2.png")

    -- Initialize the world
    self.world = World:new(128, 128, 16) -- width, height, tile size
    self.world:generate()

    -- Find a good starting position near the surface
    local startX = 64 * self.world.tileSize -- Middle of the world horizontally
    local startY = 0

    -- Find the ground level at this X position by moving down until we hit solid ground
    for y = 1, self.world.height do
        if self.world:isSolid(startX, y * self.world.tileSize) then
            startY = (y - 1) * self.world.tileSize - 20 -- Position player just above the ground
            break
        end
    end

    -- If no ground found, use a default position
    if startY == 0 then
        startY = math.floor(self.world.height * 0.5) * self.world.tileSize
    end

    -- Initialize the player
    self.player = Player:new(self.world, startX, startY)

    -- Initialize the camera
    self.camera = Camera:new(self.width, self.height, 1) -- Use scale factor of 1 instead of world.tileSize
    self.camera:follow(self.player)

    -- Game state
    self.paused = false
end

function Game:update(dt)
    if self.paused then
        return
    end

    -- Update the player
    self.player:update(dt)

    -- Update the camera to follow the player
    self.camera:update(dt)

    -- Update mouse position
    self.mouseX, self.mouseY = love.mouse.getPosition()
end

function Game:draw()
    -- Clear screen with default color (will be covered by background)
    love.graphics.clear(0, 0, 0)

    -- Draw the background image (tiled to fill the screen)
    love.graphics.setColor(1, 1, 1)
    local bgScaleX = self.width / self.backgroundImage:getWidth()
    local bgScaleY = self.height / self.backgroundImage:getHeight()
    love.graphics.draw(self.backgroundImage, 0, 0, 0, bgScaleX, bgScaleY)

    -- Begin camera transformation
    self.camera:set()

    -- Draw the world
    self.world:draw(self.camera)

    -- Draw the player
    self.player:draw()

    -- Draw block placement preview
    if self.isPlacingBlock or self.isRemovingBlock then
        local worldX, worldY = self.camera:screenToWorld(self.mouseX, self.mouseY)
        local gridX = math.floor(worldX / self.world.tileSize) + 1
        local gridY = math.floor(worldY / self.world.tileSize) + 1
        local pixelX = (gridX - 1) * self.world.tileSize
        local pixelY = (gridY - 1) * self.world.tileSize

        if self.isPlacingBlock then
            -- Show preview of block to be placed
            local blockType = self.player.selectedBlockType
            local block = self.world.blocks[blockType]

            if self.world.blockQuads[blockType] then
                -- Draw semi-transparent sprite
                love.graphics.setColor(1, 1, 1, 0.5)

                -- Calculate scaling
                local scaleX = self.world.tileSize / self.world.tilesetSize
                local scaleY = self.world.tileSize / self.world.tilesetSize

                -- Draw the sprite
                love.graphics.draw(
                    self.world.spriteSheet,
                    self.world.blockQuads[blockType],
                    pixelX,
                    pixelY,
                    0,  -- rotation
                    scaleX,
                    scaleY
                )
            else
                -- Fallback to semi-transparent block
                love.graphics.setColor(block.color[1], block.color[2], block.color[3], 0.5)
                love.graphics.rectangle("fill", pixelX, pixelY, self.world.tileSize, self.world.tileSize)
            end

            -- Draw outline
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.rectangle("line", pixelX, pixelY, self.world.tileSize, self.world.tileSize)
        else
            -- Show removal indicator
            love.graphics.setColor(1, 0, 0, 0.3)
            love.graphics.rectangle("fill", pixelX, pixelY, self.world.tileSize, self.world.tileSize)

            -- Draw X
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.line(pixelX, pixelY, pixelX + self.world.tileSize, pixelY + self.world.tileSize)
            love.graphics.line(pixelX + self.world.tileSize, pixelY, pixelX, pixelY + self.world.tileSize)
        end
    end

    -- End camera transformation
    self.camera:unset()

    -- Draw the UI on top (fixed position, not affected by camera)
    self:drawUI()
end

function Game:drawUI()
    -- Draw the UI elements here
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Princess Builder - FPS: " .. love.timer.getFPS(), 10, 10)

    -- Draw current block type indicator (in bottom left)
    local blockType = self.player.selectedBlockType
    local block = self.world.blocks[blockType]
    local blockSize = 32
    local margin = 10
    local labelX = 10
    local labelY = self.height - blockSize - margin - 20

    -- Draw label
    love.graphics.print("Selected Block: " .. block.name, labelX, labelY)

    -- Draw block preview
    love.graphics.setColor(1, 1, 1, 1)
    if self.world.blockQuads[blockType] then
        -- Calculate scaling to match display size
        local scaleX = blockSize / self.world.tilesetSize
        local scaleY = blockSize / self.world.tilesetSize

        -- Draw the sprite
        love.graphics.draw(
            self.world.spriteSheet,
            self.world.blockQuads[blockType],
            labelX,
            labelY + 20,
            0,  -- rotation
            scaleX,
            scaleY
        )
    else
        -- Fallback to colored rectangle
        love.graphics.setColor(block.color)
        love.graphics.rectangle("fill", labelX, labelY + 20, blockSize, blockSize)
    end

    -- Draw block outline
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("line", labelX, labelY + 20, blockSize, blockSize)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw controls help
    love.graphics.print("Mouse Wheel: Change Block Type", labelX + blockSize + margin, labelY)
    love.graphics.print("Left Click: Remove Block", labelX + blockSize + margin, labelY + 20)
    love.graphics.print("Right Click: Place Block", labelX + blockSize + margin, labelY + 40)

    -- Draw block selection hotbar at the bottom of the screen
    self:drawBlockHotbar()
end

function Game:drawBlockHotbar()
    local blockSize = 40
    local margin = 5
    local totalBlocks = #self.player.blockTypes
    local hotbarWidth = (blockSize + margin) * totalBlocks - margin
    local hotbarX = (self.width - hotbarWidth) / 2
    local hotbarY = self.height - blockSize - margin

    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", hotbarX - margin, hotbarY - margin,
                            hotbarWidth + margin * 2, blockSize + margin * 2, 5, 5)

    -- Draw each block in the hotbar
    for i, blockTypeId in ipairs(self.player.blockTypes) do
        local block = self.world.blocks[blockTypeId]
        local x = hotbarX + (i - 1) * (blockSize + margin)
        local y = hotbarY

        -- Draw the block
        love.graphics.setColor(1, 1, 1, 1)
        if self.world.blockQuads[blockTypeId] then
            -- Calculate scaling to match display size
            local scaleX = blockSize / self.world.tilesetSize
            local scaleY = blockSize / self.world.tilesetSize

            -- Draw the sprite
            love.graphics.draw(
                self.world.spriteSheet,
                self.world.blockQuads[blockTypeId],
                x,
                y,
                0,  -- rotation
                scaleX,
                scaleY
            )
        else
            -- Fallback to colored rectangle
            love.graphics.setColor(block.color)
            love.graphics.rectangle("fill", x, y, blockSize, blockSize)
        end

        -- Draw outline
        if self.player.blockTypeIndex == i then
            -- Highlight selected block
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 2, y - 2, blockSize + 4, blockSize + 4)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("line", x, y, blockSize, blockSize)
        end

        -- Draw block number (1-5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(i, x + 5, y + 5)
    end

    -- Reset color and line width
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Game:keypressed(key)
    if key == "escape" then
        self.paused = not self.paused
    end

    -- Number keys 1-5 for selecting block types
    local num = tonumber(key)
    if num and num >= 1 and num <= #self.player.blockTypes then
        self.player:selectBlockType(num)
    end

    if not self.paused then
        self.player:keypressed(key)
    end
end

function Game:keyreleased(key)
    if not self.paused then
        self.player:keyreleased(key)
    end
end

function Game:mousepressed(x, y, button)
    if not self.paused then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = self.camera:screenToWorld(x, y)

        -- Handle block placement/removal
        if button == 1 then -- Left click
            self.world:removeBlock(worldX, worldY)
            self.isRemovingBlock = true
        elseif button == 2 then -- Right click
            self.world:placeBlock(worldX, worldY, self.player.selectedBlockType)
            self.isPlacingBlock = true
        end
    end
end

function Game:mousereleased(x, y, button)
    -- Handle mouse release events
    if button == 1 then -- Left click
        self.isRemovingBlock = false
    elseif button == 2 then -- Right click
        self.isPlacingBlock = false
    end
end

function Game:wheelmoved(x, y)
    -- Change selected block type
    if y > 0 then
        self.player:nextBlockType()
    elseif y < 0 then
        self.player:prevBlockType()
    end
end

return Game