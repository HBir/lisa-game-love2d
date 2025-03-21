-- UI class to handle all user interface rendering
local UI = {}
UI.__index = UI

function UI:new(game)
    local self = setmetatable({}, UI)
    self.game = game  -- Store reference to the game object

    -- UI state variables
    self.saveMessage = nil

    return self
end

function UI:drawUI()
    -- Draw the UI elements here
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw current block type indicator (in bottom left)
    local blockType = self.game.player.selectedBlockType
    local block = self.game.world.blocks[blockType]
    local blockSize = 32
    local margin = 10
    local labelX = 10
    local labelY = self.game.height - blockSize - margin - 20

    -- Draw save/load message if present
    if self.saveMessage then
        -- Position message at top center of screen
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(self.saveMessage.text)
        local x = (self.game.width - textWidth) / 2
        local y = 40

        -- Draw a semi-transparent background for better readability
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x - 10, y - 5, textWidth + 20, 30)

        -- Draw the message text
        love.graphics.setColor(self.saveMessage.color)
        love.graphics.print(self.saveMessage.text, x, y)

        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw block preview
    love.graphics.setColor(1, 1, 1, 1)
    if self.game.world.blockQuads[blockType .. "_TOP"] then
        -- Calculate scaling to match display size
        local scaleX = blockSize / self.game.world.tilesetSize
        local scaleY = blockSize / self.game.world.tilesetSize

        -- Draw the sprite
        love.graphics.draw(
            self.game.world.spriteSheet,
            self.game.world.blockQuads[blockType .. "_TOP"],
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

    -- Draw controls help
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("F5: Save World  |  F9: Load World", self.game.width - 250, 10)

    -- Draw block selection hotbar at the bottom of the screen
    self:drawBlockHotbar()
end

function UI:drawBlockHotbar()
    local blockSize = 40
    local margin = 5
    local totalBlocks = #self.game.player.blockTypes
    local hotbarWidth = (blockSize + margin) * totalBlocks - margin
    local hotbarX = (self.game.width - hotbarWidth) / 2
    local hotbarY = self.game.height - blockSize - margin

    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", hotbarX - margin, hotbarY - margin,
                            hotbarWidth + margin * 2, blockSize + margin * 2, 5, 5)

    -- Draw each block in the hotbar
    for i, blockTypeId in ipairs(self.game.player.blockTypes) do
        local block = self.game.world.blocks[blockTypeId]
        local x = hotbarX + (i - 1) * (blockSize + margin)
        local y = hotbarY

        -- Draw the block
        love.graphics.setColor(1, 1, 1, 1)
        if self.game.world.blockQuads[blockTypeId .. "_TOP"] then
            -- Calculate scaling to match display size
            local scaleX = blockSize / self.game.world.tilesetSize
            local scaleY = blockSize / self.game.world.tilesetSize

            -- Draw the sprite
            love.graphics.draw(
                self.game.world.spriteSheet,
                self.game.world.blockQuads[blockTypeId .. "_TOP"],
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
        if self.game.player.blockTypeIndex == i then
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

function UI:drawLisaProgress()
    -- Only display the progress if the sequence has been started (at least "L" pressed)
    if self.game.particles.lisaSequence.displayTimer > 0 and self.game.particles.lisaSequence.currentIndex > 0 then
        local sequence = "LISA"
        local font = love.graphics.getFont()
        local letterSpacing = 40  -- Increased from 30 to 40 for more space between letters
        local totalWidth = letterSpacing * (#sequence - 1) + font:getWidth(sequence) * 2  -- Adjusted for larger letters
        local x = (self.game.width - totalWidth) / 2
        local y = 470

        -- Draw a semi-transparent background for better visibility
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", x - 20, y - 10, totalWidth, 60, 10, 10)

        for i = 1, #sequence do
            local letter = sequence:sub(i, i)
            local letterX = x + (i - 1) * letterSpacing

            if i <= self.game.particles.lisaSequence.currentIndex then
                -- Draw completed letters in bright yellow (more visible than green)
                love.graphics.setColor(1, 0.9, 0.2, 1)  -- Bright yellow

                -- Add glow effect for completed letters
                love.graphics.setColor(1, 0.9, 0.2, 0.3)  -- Transparent yellow for glow
                love.graphics.circle("fill", letterX + font:getWidth(letter), y + 15, 20)

                -- Draw the actual letter
                love.graphics.setColor(1, 0.9, 0.2, 1)  -- Bright yellow
            else
                -- Draw pending letters in white/silver (more visible than gray)
                love.graphics.setColor(0.9, 0.9, 1, 0.8)  -- Bright silver/white
            end

            -- Draw letter with larger scaling (increased from 1.5/1.0 to 2.0/1.5)
            local scale = i <= self.game.particles.lisaSequence.currentIndex and 2.0 or 1.5
            love.graphics.print(letter, letterX, y, 0, scale, scale)

            -- Draw a subtle outline for better contrast against any background
            if i <= self.game.particles.lisaSequence.currentIndex then
                love.graphics.setColor(0.5, 0.5, 0, 0.5)  -- Dark yellow outline
            else
                love.graphics.setColor(0.1, 0.1, 0.2, 0.5)  -- Dark blue/black outline
            end
            love.graphics.setLineWidth(2)
            love.graphics.print(letter, letterX + 1, y + 1, 0, scale, scale)
            love.graphics.setLineWidth(1)
        end

        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Drawing the block placement preview
function UI:drawBlockPlacementPreview()
    if self.game.inputs.isPlacingBlock or self.game.inputs.isRemovingBlock then
        local worldX, worldY = self.game.camera:screenToWorld(self.game.inputs.mouseX, self.game.inputs.mouseY)
        local gridX = math.floor(worldX / self.game.world.tileSize) + 1
        local gridY = math.floor(worldY / self.game.world.tileSize) + 1
        local pixelX = (gridX - 1) * self.game.world.tileSize
        local pixelY = (gridY - 1) * self.game.world.tileSize

        if self.game.inputs.isPlacingBlock then
            -- Show preview of block to be placed
            local blockType = self.game.player.selectedBlockType
            local block = self.game.world.blocks[blockType]

            if self.game.world.blockQuads[blockType .. "_TOP"] then
                -- Draw semi-transparent sprite
                love.graphics.setColor(1, 1, 1, 0.5)

                -- Calculate scaling
                local scaleX = self.game.world.tileSize / self.game.world.tilesetSize
                local scaleY = self.game.world.tileSize / self.game.world.tilesetSize

                -- Draw the sprite
                love.graphics.draw(
                    self.game.world.spriteSheet,
                    self.game.world.blockQuads[blockType  .. "_TOP"],
                    pixelX,
                    pixelY,
                    0,  -- rotation
                    scaleX,
                    scaleY
                )
            else
                -- Fallback to semi-transparent block
                love.graphics.setColor(block.color[1], block.color[2], block.color[3], 0.5)
                love.graphics.rectangle("fill", pixelX, pixelY, self.game.world.tileSize, self.game.world.tileSize)
            end

            -- Draw outline
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.rectangle("line", pixelX, pixelY, self.game.world.tileSize, self.game.world.tileSize)
        else
            -- Show removal indicator
            love.graphics.setColor(1, 0, 0, 0.3)
            love.graphics.rectangle("fill", pixelX, pixelY, self.game.world.tileSize, self.game.world.tileSize)

            -- Draw X
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.line(pixelX, pixelY, pixelX + self.game.world.tileSize, pixelY + self.game.world.tileSize)
            love.graphics.line(pixelX + self.game.world.tileSize, pixelY, pixelX, pixelY + self.game.world.tileSize)
        end
    end
end

-- Function to draw the sprite debug view
function UI:drawSpriteDebug()
    -- Get the sprite sheet and tilesize from the block registry
    local spriteSheet = self.game.world.blockRegistry.spriteSheet
    local tileSize = self.game.world.blockRegistry.tilesetSize

    -- Calculate how many sprites fit per row based on window width
    local columns = 11 --math.floor(self.game.width / (tileSize * 4))
    local spacing = 0 -- Space between sprites horizontally
    local verticalSpacing = 35 -- Increased vertical spacing to make room for text
    local scale = 3 -- Scale up sprites for better visibility

    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, self.game.width, self.game.height)

    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SPRITE DEBUG VIEW (Press X to exit)", 10, 10)


    local quads = self.game.world.blockRegistry.blockQuads
    -- Draw each sprite
    local row = 0
    local col = 0
    local startY = 50 -- Start below the title, increased for better spacing

    -- sort quads
    local sortedQuads = {}

    for key, quad in pairs(quads) do
        table.insert(sortedQuads, {key = key, quad = quad})
    end

    table.sort(sortedQuads, function(a, b)
        return tostring(a.key) < tostring(b.key)
    end)

    for _, quad in pairs(sortedQuads) do
        local x = 10 + col * (tileSize * scale + spacing)
        local y = startY + row * (tileSize * scale + verticalSpacing)

        -- Draw sprite
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(spriteSheet, quad.quad, x, y, 0, scale, scale)

        -- -- Draw border around the sprite
        -- love.graphics.setColor(0.5, 0.5, 0.5, 1)
        -- love.graphics.rectangle("line", x - 1, y - 1, tileSize * scale + 2, tileSize * scale + 2)

        local blockTypeStr = tostring(quad.key)
        local textWidth = blockTypeStr:len() * 6 -- Approximate width
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x, y + tileSize * scale + 2, textWidth, 14)
        -- Draw the text
        love.graphics.setColor(1, 1, 0.5, 1)
        love.graphics.print(blockTypeStr, x, y + tileSize * scale + 2, 0, 0.8, 0.8)

        -- Move to next column or row
        col = col + 1
        if col >= columns then
            col = 0
            row = row + 1
        end
    end
end

-- Update the save message timer
function UI:updateSaveMessage(dt)
    if self.saveMessage then
        self.saveMessage.timer = self.saveMessage.timer - dt
        if self.saveMessage.timer <= 0 then
            self.saveMessage = nil
        end
    end
end

-- Set a save/load message to display
function UI:setSaveMessage(text, color, duration)
    self.saveMessage = {
        text = text,
        timer = duration or 3, -- Default to 3 seconds
        color = color or {0, 1, 0, 1} -- Default to green
    }
end

return UI
