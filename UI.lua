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

    -- If the game is paused, draw the pause menu and return
    if self.game.paused then
        self:drawPauseMenu()
        return
    end

    -- Draw current block type indicator (in bottom left)
    local blockType = self.game.player.selectedBlockType
    local block = self.game.world.blockRegistry:getBlock(blockType)
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
    if self.game.world.blockRegistry.blockQuads[blockType .. "_TOP"] then
        -- Calculate scaling to match display size
        local scaleX = blockSize / self.game.world.blockRegistry.tilesetSize
        local scaleY = blockSize / self.game.world.blockRegistry.tilesetSize

        -- Draw the sprite
        love.graphics.draw(
            self.game.world.blockRegistry.spriteSheet,
            self.game.world.blockRegistry.blockQuads[blockType .. "_TOP"],
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
        local block = self.game.world.blockRegistry.blocks[blockTypeId]
        local x = hotbarX + (i - 1) * (blockSize + margin)
        local y = hotbarY

        -- Draw the block
        love.graphics.setColor(1, 1, 1, 1)
        if self.game.world.blockRegistry.blockQuads[blockTypeId .. "_TOP"] then
            -- Calculate scaling to match display size
            local scaleX = blockSize / self.game.world.blockRegistry.tilesetSize
            local scaleY = blockSize / self.game.world.blockRegistry.tilesetSize

            -- Draw the sprite
            love.graphics.draw(
                self.game.world.blockRegistry.spriteSheet,
                self.game.world.blockRegistry.blockQuads[blockTypeId .. "_TOP"],
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
            local block = self.game.world.blockRegistry.blocks[blockType]

            if self.game.world.blockRegistry.blockQuads[blockType .. "_TOP"] then
                -- Draw semi-transparent sprite
                love.graphics.setColor(1, 1, 1, 0.5)

                -- Calculate scaling
                local scaleX = self.game.world.tileSize / self.game.world.blockRegistry.tilesetSize
                local scaleY = self.game.world.tileSize / self.game.world.blockRegistry.tilesetSize

                -- Draw the sprite
                love.graphics.draw(
                    self.game.world.spriteSheet,
                    self.game.world.blockRegistry.blockQuads[blockType  .. "_TOP"],
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
function UI:drawSpriteDebug(page)
    page = page or 1  -- Default to page 1 if no page is specified

    -- Common setup for all debug pages
    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, self.game.width, self.game.height)

    -- Page-specific content
    if page == 1 or page == 2 then
        -- SPRITE DEBUG VIEW (page 1 shows top portion, page 2 shows more blocks)
        -- Draw title with page information
        love.graphics.setColor(1, 1, 1, 1)
        if page == 1 then
            love.graphics.print("SPRITE DEBUG VIEW - PAGE 1 (Press X to see more sprites)", 10, 10)
        else
            love.graphics.print("SPRITE DEBUG VIEW - PAGE 2 (Press X to close)", 10, 10)
        end

        -- Get the sprite sheet and tilesize from the block registry
        local spriteSheet = self.game.world.blockRegistry.spriteSheet
        local tileSize = self.game.world.blockRegistry.tilesetSize

        -- Calculate how many sprites fit per row based on window width
        local columns = 11 --math.floor(self.game.width / (tileSize * 4))
        local spacing = 0 -- Space between sprites horizontally
        local verticalSpacing = 35 -- Increased vertical spacing to make room for text
        local scale = 3 -- Scale up sprites for better visibility

        -- Calculate rows per page
        local rowsPerPage = math.floor((self.game.height - 60) / (tileSize * scale + verticalSpacing))

        local quads = self.game.world.blockRegistry.blockQuads

        -- sort quads
        local sortedQuads = {}
        for key, quad in pairs(quads) do
            table.insert(sortedQuads, {key = key, quad = quad})
        end

        table.sort(sortedQuads, function(a, b)
            return tostring(a.key) < tostring(b.key)
        end)

        -- Calculate starting row based on current page
        local pageOffset = (page - 1) * rowsPerPage

        -- Draw each sprite
        local row = 0
        local col = 0
        local startY = 50 -- Start below the title, increased for better spacing
        local displayedRows = 0
        local totalRows = math.ceil(#sortedQuads / columns)

        local shownCount = 0

        for i, quad in pairs(sortedQuads) do
            -- Calculate which row and column this sprite belongs to
            local spriteRow = math.floor((i-1) / columns)
            local spriteCol = (i-1) % columns

            -- Only display sprites for the current page
            if spriteRow >= pageOffset and spriteRow < pageOffset + rowsPerPage then
                local adjustedRow = spriteRow - pageOffset
                local x = 10 + spriteCol * (tileSize * scale + spacing)
                local y = startY + adjustedRow * (tileSize * scale + verticalSpacing)

                -- Draw sprite
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(spriteSheet, quad.quad, x, y, 0, scale, scale)

                local blockTypeStr = tostring(quad.key)
                local textWidth = blockTypeStr:len() * 6 -- Approximate width
                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.rectangle("fill", x, y + tileSize * scale + 2, textWidth, 14)
                -- Draw the text
                love.graphics.setColor(1, 1, 0.5, 1)
                love.graphics.print(blockTypeStr, x, y + tileSize * scale + 2, 0, 0.8, 0.8)

                shownCount = shownCount + 1
            end
        end

        -- Show page information at the bottom
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("Showing " .. shownCount .. " of " .. #sortedQuads .. " sprites (Page " .. page .. " of " .. math.ceil(totalRows / rowsPerPage) .. ")",
                           10, self.game.height - 30)

    elseif page == 3 then
        -- GAME STATS PAGE (now page 3)
        -- Draw title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("GAME STATS DEBUG (Press X to close)", 10, 10)

        -- Draw game stats
        local startY = 50
        local lineHeight = 24
        local statsX = 20

        -- Player information
        love.graphics.setColor(0.8, 1, 0.8, 1) -- Light green for player stats
        love.graphics.print("PLAYER STATS:", statsX, startY)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Position: X=" .. math.floor(self.game.player.x) .. ", Y=" .. math.floor(self.game.player.y),
                           statsX + 20, startY + lineHeight)
        love.graphics.print("Velocity: X=" .. string.format("%.2f", self.game.player.vx) ..
                           ", Y=" .. string.format("%.2f", self.game.player.vy),
                           statsX + 20, startY + lineHeight * 2)
        love.graphics.print("Animation: " .. self.game.player.animation.state .. " (Frame " ..
                           self.game.player.animation.frame .. ")",
                           statsX + 20, startY + lineHeight * 3)
        love.graphics.print("On Ground: " .. tostring(self.game.player.onGround),
                           statsX + 20, startY + lineHeight * 4)

        -- World information
        love.graphics.setColor(0.8, 0.8, 1, 1) -- Light blue for world stats
        love.graphics.print("WORLD STATS:", statsX, startY + lineHeight * 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("World Size: " .. self.game.world.width .. " x " .. self.game.world.height .. " tiles",
                           statsX + 20, startY + lineHeight * 7)
        love.graphics.print("Tile Size: " .. self.game.world.tileSize .. " pixels",
                           statsX + 20, startY + lineHeight * 8)

        -- Camera information
        love.graphics.setColor(1, 0.8, 0.8, 1) -- Light red for camera stats
        love.graphics.print("CAMERA STATS:", statsX, startY + lineHeight * 10)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Position: X=" .. math.floor(self.game.camera.x) .. ", Y=" .. math.floor(self.game.camera.y),
                           statsX + 20, startY + lineHeight * 11)
        love.graphics.print("Scale: " .. self.game.camera.scale,
                           statsX + 20, startY + lineHeight * 12)

        -- NPC count
        love.graphics.setColor(1, 1, 0.8, 1) -- Light yellow for NPC stats
        love.graphics.print("NPC STATS:", statsX, startY + lineHeight * 14)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Active NPCs: " .. #self.game.npcs,
                           statsX + 20, startY + lineHeight * 15)

        -- Performance metrics (if available)
        love.graphics.setColor(1, 0.8, 1, 1) -- Light purple for performance stats
        love.graphics.print("PERFORMANCE:", statsX, startY + lineHeight * 17)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("FPS: " .. love.timer.getFPS(),
                           statsX + 20, startY + lineHeight * 18)
        love.graphics.print("Memory Used: " .. string.format("%.2f", collectgarbage("count") / 1024) .. " MB",
                           statsX + 20, startY + lineHeight * 19)
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

-- Drawing the pause menu
function UI:drawPauseMenu()
    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, self.game.width, self.game.height)

    -- Menu container
    local menuWidth = 300
    local menuHeight = 250
    local menuX = (self.game.width - menuWidth) / 2
    local menuY = (self.game.height - menuHeight) / 2

    -- Draw menu background
    love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, 10, 10)
    love.graphics.setColor(0.4, 0.4, 0.6, 1)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight, 10, 10)

    -- Draw menu title
    love.graphics.setColor(1, 1, 1, 1)
    local titleText = "Game Paused"
    local font = love.graphics.getFont()
    local titleWidth = font:getWidth(titleText) * 1.5 -- Scale for larger text
    local titleX = menuX + (menuWidth - titleWidth) / 2
    love.graphics.print(titleText, titleX, menuY + 20, 0, 1.5, 1.5)

    -- Draw menu options
    love.graphics.setColor(1, 1, 1, 0.9)

    -- Button dimensions
    local buttonWidth = 200
    local buttonHeight = 40
    local buttonX = menuX + (menuWidth - buttonWidth) / 2
    local buttonSpacing = 20
    local buttonY = menuY + 80

    -- Resume button
    local resumeButtonY = buttonY
    love.graphics.setColor(0.3, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", buttonX, resumeButtonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(0.2, 0.3, 0.2, 1)
    love.graphics.rectangle("line", buttonX, resumeButtonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    local resumeText = "Resume Game"
    local resumeTextWidth = font:getWidth(resumeText)
    love.graphics.print(resumeText, buttonX + (buttonWidth - resumeTextWidth) / 2, resumeButtonY + 10)

    -- Save button
    local saveButtonY = buttonY + buttonHeight + buttonSpacing
    love.graphics.setColor(0.3, 0.3, 0.5, 1)
    love.graphics.rectangle("fill", buttonX, saveButtonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(0.2, 0.2, 0.3, 1)
    love.graphics.rectangle("line", buttonX, saveButtonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    local saveText = "Save Game"
    local saveTextWidth = font:getWidth(saveText)
    love.graphics.print(saveText, buttonX + (buttonWidth - saveTextWidth) / 2, saveButtonY + 10)

    -- Load button
    local loadButtonY = saveButtonY + buttonHeight + buttonSpacing
    love.graphics.setColor(0.3, 0.3, 0.5, 1)
    love.graphics.rectangle("fill", buttonX, loadButtonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(0.2, 0.2, 0.3, 1)
    love.graphics.rectangle("line", buttonX, loadButtonY, buttonWidth, buttonHeight, 5, 5)
    love.graphics.setColor(1, 1, 1, 1)
    local loadText = "Load Game"
    local loadTextWidth = font:getWidth(loadText)
    love.graphics.print(loadText, buttonX + (buttonWidth - loadTextWidth) / 2, loadButtonY + 10)

    -- Store button positions and dimensions for interaction
    self.pauseMenu = {
        resume = {x = buttonX, y = resumeButtonY, width = buttonWidth, height = buttonHeight},
        save = {x = buttonX, y = saveButtonY, width = buttonWidth, height = buttonHeight},
        load = {x = buttonX, y = loadButtonY, width = buttonWidth, height = buttonHeight}
    }

    -- Draw esc to resume hint
    love.graphics.setColor(0.8, 0.8, 0.8, 0.7)
    local hintText = "Press ESC again to resume"
    local hintWidth = font:getWidth(hintText)
    love.graphics.print(hintText, menuX + (menuWidth - hintWidth) / 2, menuY + menuHeight - 30)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Check if point is inside rectangle
function UI:pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.width and
           y >= rect.y and y <= rect.y + rect.height
end

-- Function to handle pause menu clicks
function UI:handlePauseMenuClick(x, y)
    if not self.pauseMenu then return false end

    if self:pointInRect(x, y, self.pauseMenu.resume) then
        self.game.paused = false
        return true
    elseif self:pointInRect(x, y, self.pauseMenu.save) then
        self.game:saveWorld()
        return true
    elseif self:pointInRect(x, y, self.pauseMenu.load) then
        self.game:loadWorld()
        return true
    end

    return false
end

return UI
