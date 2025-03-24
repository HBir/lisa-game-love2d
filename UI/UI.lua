-- UI class to handle all user interface rendering
local UI = {}
UI.__index = UI

local DebugMenu = require("UI.DebugMenu")
local PauseMenu = require("UI.PauseMenu")

function UI:new(game)
    local self = setmetatable({}, UI)
    self.game = game  -- Store reference to the game object

    -- UI state variables
    self.saveMessage = nil

    self.pauseMenu = PauseMenu:new(game)

    return self
end

function UI:drawUI()
    -- Draw the UI elements here
    love.graphics.setColor(1, 1, 1, 1)

    -- If the game is paused, draw the pause menu and return
    if self.game.paused then
        self.pauseMenu:drawPauseMenu()
        return
    end

    -- Draw current selected item indicator (in bottom left)
    local blockSize = 32
    local margin = 10
    local labelX = 10
    local labelY = self.game.height - blockSize - margin - 20

    -- Check if we're in furniture mode or block mode
    if self.game.player.furnitureMode then
        -- Draw furniture preview
        local furnitureType = self.game.player.selectedFurnitureType
        local furniture = self.game.world.furnitureRegistry:getFurniture(furnitureType)

        if furniture then
            love.graphics.setColor(1, 1, 1, 1)
            local quad = self.game.world.furnitureRegistry:getQuad(furnitureType)

            if quad then
                -- Get furniture dimensions
                local spriteW, spriteH = self.game.world.furnitureRegistry:getSpriteSize(furnitureType)
                local gridW, gridH = furniture.width, furniture.height

                -- Calculate scale to fit in a reasonable preview area
                local maxPreviewWidth = blockSize * 2
                local maxPreviewHeight = blockSize * 2
                local scaleX = math.min(maxPreviewWidth / spriteW, maxPreviewHeight / spriteH)
                local scaleY = scaleX

                -- Draw the furniture sprite
                love.graphics.draw(
                    self.game.world.furnitureRegistry.spriteSheet,
                    quad,
                    labelX,
                    labelY + 20,
                    0,  -- rotation
                    scaleX,
                    scaleY
                )
            else
                -- Fallback to colored rectangle
                love.graphics.setColor(furniture.color)
                love.graphics.rectangle("fill", labelX, labelY + 20, blockSize, blockSize)
            end

            -- Draw outline
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("line", labelX, labelY + 20, blockSize, blockSize)
        end
    else
        -- Original block preview code
        local blockType = self.game.player.selectedBlockType
        local block = self.game.world.blockRegistry:getBlock(blockType)

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
    end

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

    -- Draw creature team indicator in top right if player has creatures
    if self.game.player.creatureTeam and #self.game.player.creatureTeam.creatures > 0 then
        self:drawCreatureTeamIndicator()
    end

    -- Draw selection hotbar at the bottom of the screen
    if self.game.player.furnitureMode then
        self:drawFurnitureHotbar()
    else
        self:drawBlockHotbar()
    end
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
    if self.game.inputs.showPreview or self.game.inputs.isPlacingBlock or self.game.inputs.isRemovingBlock then
        -- Use the already calculated world coordinates from Inputs
        local worldX = self.game.inputs.mouseWorldX
        local worldY = self.game.inputs.mouseWorldY

        local gridX = math.floor(worldX / self.game.world.tileSize) + 1
        local gridY = math.floor(worldY / self.game.world.tileSize) + 1
        local pixelX = (gridX - 1) * self.game.world.tileSize
        local pixelY = (gridY - 1) * self.game.world.tileSize

        -- Show preview of block to be placed
        local blockType = self.game.player.selectedBlockType
        local block = self.game.world.blockRegistry:getBlock(blockType)

        -- Get the appropriate quad for this block
        local quad = self.game.world.blockRegistry:getQuad(blockType, "TOP")

        if quad then
            -- Draw semi-transparent sprite
            love.graphics.setColor(1, 1, 1, 0.5)

            -- Draw the sprite
            love.graphics.draw(
                self.game.world.blockRegistry.spriteSheet,
                quad,
                pixelX,
                pixelY
            )
        else
            -- Fallback to colored rectangle if no sprite is available
            love.graphics.setColor(block.color[1], block.color[2], block.color[3], 0.5)
            love.graphics.rectangle("fill", pixelX, pixelY, self.game.world.tileSize, self.game.world.tileSize)

            -- Draw outline
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("line", pixelX, pixelY, self.game.world.tileSize, self.game.world.tileSize)
        end

        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
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
   self.pauseMenu:drawPauseMenu()
end

function UI:drawDebugMenu(page)
    DebugMenu:DrawDebugMenu(page, self.game)
end

-- Draw the furniture selection hotbar
function UI:drawFurnitureHotbar()
    local itemSize = 48  -- Slightly larger than block hotbar for better furniture visibility
    local margin = 5
    local totalItems = #self.game.player.furnitureTypes
    local hotbarWidth = (itemSize + margin) * totalItems - margin
    local hotbarX = (self.game.width - hotbarWidth) / 2
    local hotbarY = self.game.height - itemSize - margin

    -- Draw background with different color to distinguish from block hotbar
    love.graphics.setColor(0.2, 0.2, 0.4, 0.7)  -- Slightly blueish tint
    love.graphics.rectangle("fill", hotbarX - margin, hotbarY - margin,
                           hotbarWidth + margin * 2, itemSize + margin * 2, 5, 5)

    -- Draw title to indicate furniture mode
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.print("FURNITURE MODE (TAB to exit)", hotbarX, hotbarY - 20)

    -- Draw each furniture item in the hotbar
    for i, furnitureTypeId in ipairs(self.game.player.furnitureTypes) do
        local furniture = self.game.world.furnitureRegistry:getFurniture(furnitureTypeId)
        if furniture then
            local x = hotbarX + (i - 1) * (itemSize + margin)
            local y = hotbarY

            -- Draw furniture item
            love.graphics.setColor(1, 1, 1, 1)
            local quad = self.game.world.furnitureRegistry:getQuad(furnitureTypeId)

            if quad then
                -- Get furniture dimensions
                local spriteW, spriteH = self.game.world.furnitureRegistry:getSpriteSize(furnitureTypeId)

                -- Calculate scale to fit in hotbar slot
                local scaleX = itemSize / spriteW
                local scaleY = itemSize / spriteH

                -- Use the smaller scale to maintain aspect ratio
                local scale = math.min(scaleX, scaleY)

                -- Center the sprite in the slot
                local offsetX = (itemSize - (spriteW * scale)) / 2
                local offsetY = (itemSize - (spriteH * scale)) / 2

                -- Draw the sprite
                love.graphics.draw(
                    self.game.world.furnitureRegistry.spriteSheet,
                    quad,
                    x + offsetX,
                    y + offsetY,
                    0,  -- rotation
                    scale,
                    scale
                )
            else
                -- Fallback to colored rectangle
                love.graphics.setColor(furniture.color)
                love.graphics.rectangle("fill", x, y, itemSize, itemSize)
            end

            -- Draw outline
            if self.game.player.furnitureTypeIndex == i then
                -- Highlight selected furniture
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x - 2, y - 2, itemSize + 4, itemSize + 4)
                love.graphics.setLineWidth(1)

                -- Draw name of selected furniture
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(furniture.name, x, y + itemSize + 5)

                -- Draw size information
                love.graphics.setColor(0.8, 0.8, 1, 0.9)
                love.graphics.print(furniture.width .. "x" .. furniture.height, x, y + itemSize + 20)
            else
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.rectangle("line", x, y, itemSize, itemSize)
            end

            -- Draw furniture number
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(i, x + 5, y + 5)
        end
    end

    -- Reset color and line width
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Draw a small indicator showing the player's active creature
function UI:drawCreatureTeamIndicator()
    local activeCreature = self.game.player.creatureTeam:getActiveCreature()
    if not activeCreature then return end

    -- Position in top right
    local indicatorX = self.game.width - 120
    local indicatorY = 10
    local indicatorWidth = 110
    local indicatorHeight = 50

    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorWidth, indicatorHeight, 5, 5)

    -- Draw creature name and level
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(activeCreature.name, indicatorX + 5, indicatorY + 5)
    love.graphics.print("Lv. " .. activeCreature.level, indicatorX + 70, indicatorY + 5)

    -- Draw HP bar
    local hpBarWidth = 100
    local hpBarHeight = 8
    local filledWidth = (activeCreature.currentHp / activeCreature.stats.hp) * hpBarWidth

    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", indicatorX + 5, indicatorY + 25, hpBarWidth, hpBarHeight)

    -- Filled portion
    local hpColor = {0.2, 0.8, 0.2}  -- Green
    if activeCreature.currentHp <= activeCreature.stats.hp * 0.5 then
        hpColor = {0.8, 0.8, 0.2}  -- Yellow
    end
    if activeCreature.currentHp <= activeCreature.stats.hp * 0.25 then
        hpColor = {0.8, 0.2, 0.2}  -- Red
    end

    love.graphics.setColor(hpColor)
    love.graphics.rectangle("fill", indicatorX + 5, indicatorY + 25, filledWidth, hpBarHeight)

    -- Draw HP text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(activeCreature.currentHp .. "/" .. activeCreature.stats.hp,
                       indicatorX + 5, indicatorY + 33)

    -- Draw hint for team screen
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
    love.graphics.print("T: Team", indicatorX + 70, indicatorY + 33)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return UI
