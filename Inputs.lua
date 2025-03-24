-- Inputs module for handling all input-related functionality
local Inputs = {}
Inputs.__index = Inputs

-- Initialize a new Inputs instance
function Inputs:new(game)
    local self = setmetatable({}, Inputs)
    self.game = game

    -- Mouse position in world coordinates
    self.mouseWorldX = 0
    self.mouseWorldY = 0

    -- Block placement state
    self.isPlacingBlock = false
    self.isRemovingBlock = false

    -- Block placement preview (for background layer)
    self.showPreview = false
    self.previewX = 0
    self.previewY = 0
    self.previewBlockType = nil

    -- Cooldown for block placement and removal to avoid spamming
    self.blockPlacementCooldown = 0
    self.blockRemovalCooldown = 0

    -- Cooldown for furniture placement and removal
    self.furniturePlacementCooldown = 0
    self.furnitureRemovalCooldown = 0

    -- Cooldown for furniture placement preview updates
    self.furniturePreviewUpdateCooldown = 0

    return self
end

-- Update input state
function Inputs:update(dt)
    -- Get mouse position in screen space
    local mouseX, mouseY = love.mouse.getPosition()

    -- Convert mouse position to world space
    self.mouseWorldX, self.mouseWorldY = self.game.camera:screenToWorld(mouseX, mouseY)

    -- Update placement cooldowns
    if self.blockPlacementCooldown > 0 then
        self.blockPlacementCooldown = self.blockPlacementCooldown - dt
    end

    if self.blockRemovalCooldown > 0 then
        self.blockRemovalCooldown = self.blockRemovalCooldown - dt
    end

    if self.furniturePlacementCooldown > 0 then
        self.furniturePlacementCooldown = self.furniturePlacementCooldown - dt
    end

    if self.furnitureRemovalCooldown > 0 then
        self.furnitureRemovalCooldown = self.furnitureRemovalCooldown - dt
    end

    if self.furniturePreviewUpdateCooldown > 0 then
        self.furniturePreviewUpdateCooldown = self.furniturePreviewUpdateCooldown - dt
    end

    -- Handle continuous block placement/removal while mouse buttons are held
    if self.isPlacingBlock and self.blockPlacementCooldown <= 0 then
        if self.game.player.furnitureMode then
            self:handleFurniturePlacement()
        else
            self:handleBlockPlacement()
        end
    end

    if self.isRemovingBlock and self.blockRemovalCooldown <= 0 then
        if self.game.player.furnitureMode then
            self:handleFurnitureRemoval()
        else
            self:handleBlockRemoval()
        end
    end

    -- Update furniture placement preview if in furniture mode
    if self.game.player.furnitureMode and self.furniturePreviewUpdateCooldown <= 0 then
        self:updateFurniturePreview()
        self.furniturePreviewUpdateCooldown = 0.1 -- Update preview every 100ms
    end

    -- Update block placement preview
    if not self.game.player.furnitureMode and not self.isPlacingBlock and self.showPreview then
        local gridX = math.floor(self.mouseWorldX / self.game.world.tileSize) + 1
        local gridY = math.floor(self.mouseWorldY / self.game.world.tileSize) + 1

        self.previewX = (gridX - 1) * self.game.world.tileSize
        self.previewY = (gridY - 1) * self.game.world.tileSize

        self.previewBlockType = self.game.player.selectedBlockType
    end
end

-- Handle furniture placement with right-click
function Inputs:handleFurniturePlacement()
    -- Check cooldown
    if self.furniturePlacementCooldown > 0 then
        return
    end

    -- Place furniture at mouse position
    local furnitureType = self.game.player.selectedFurnitureType
    if not furnitureType then
        return
    end

    -- Check if can place furniture
    local canPlace = self.game.world:canPlaceFurniture(self.mouseWorldX, self.mouseWorldY, furnitureType)
    if canPlace then
        local success = self.game.world:placeFurniture(self.mouseWorldX, self.mouseWorldY, furnitureType)

        if success then
            -- Apply cooldown to prevent spamming
            self.furniturePlacementCooldown = 0.2

            -- Play a sound
            if self.game.sounds and self.game.sounds.placeBlock then
                self.game.sounds.placeBlock:play()
            end

            -- Update the preview
            self:updateFurniturePreview()
        end
    end
end

-- Handle furniture removal with left-click
function Inputs:handleFurnitureRemoval()
    -- Check cooldown
    if self.furnitureRemovalCooldown > 0 then
        return
    end

    -- Remove furniture at mouse position
    local furniture = self.game.world:getFurniture(self.mouseWorldX, self.mouseWorldY)
    if furniture then
        local success = self.game.world:removeFurniture(self.mouseWorldX, self.mouseWorldY)

        if success then
            -- Apply cooldown to prevent spamming
            self.furnitureRemovalCooldown = 0.2

            -- Play a sound
            if self.game.sounds and self.game.sounds.removeBlock then
                self.game.sounds.removeBlock:play()
            end

            -- Update the preview
            self:updateFurniturePreview()
        end
    end
end

-- Update the furniture placement preview
function Inputs:updateFurniturePreview()
    -- Only update if in furniture mode
    if not self.game.player.furnitureMode then
        self.game.world.renderer:hideFurniturePreview()
        return
    end

    local furnitureType = self.game.player.selectedFurnitureType
    if not furnitureType then
        self.game.world.renderer:hideFurniturePreview()
        return
    end

    -- Check if can place furniture
    local canPlace = self.game.world:canPlaceFurniture(self.mouseWorldX, self.mouseWorldY, furnitureType)

    -- Update the preview
    self.game.world.renderer:setFurniturePreview(
        furnitureType,
        self.mouseWorldX,
        self.mouseWorldY,
        canPlace
    )
end

-- Handle block placement with right-click
function Inputs:handleBlockPlacement()
    -- Check cooldown
    if self.blockPlacementCooldown > 0 then
        return
    end

    -- Place block at mouse position
    local success = self.game.world:placeBlock(self.mouseWorldX, self.mouseWorldY, self.game.player.selectedBlockType)

    if success then
        -- Apply cooldown to prevent spamming
        self.blockPlacementCooldown = 0.2

        -- Play a sound
        if self.game.sounds and self.game.sounds.placeBlock then
            self.game.sounds.placeBlock:play()
        end

        -- Create a block placement particle effect
        self.game:emitBlockPlaceParticles(self.mouseWorldX, self.mouseWorldY, self.game.player.selectedBlockType)
    end
end

-- Handle block removal with left-click
function Inputs:handleBlockRemoval()
    -- Check cooldown
    if self.blockRemovalCooldown > 0 then
        return
    end

    -- Determine which layer to target based on selected block type
    local targetLayer = nil
    local selectedBlockType = self.game.player.selectedBlockType

    -- If the selected block is not solid, it's a background block
    if not self.game.world.blockRegistry:isSolid(selectedBlockType) then
        targetLayer = "background"
    end

    -- Get block at mouse position
    local blockType = self.game.world:getBlock(self.mouseWorldX, self.mouseWorldY, targetLayer)

    -- Only try to remove non-air blocks
    if blockType ~= self.game.world.blockRegistry.BLOCK_AIR then
        -- Create a block removal particle effect before removing the block
        self.game:emitBlockBreakParticles(self.mouseWorldX, self.mouseWorldY, blockType)

        -- Remove block
        local success = self.game.world:removeBlock(self.mouseWorldX, self.mouseWorldY, targetLayer)

        if success then
            -- Apply cooldown to prevent spamming
            self.blockRemovalCooldown = 0.2

            -- Play a sound
            if self.game.sounds and self.game.sounds.removeBlock then
                self.game.sounds.removeBlock:play()
            end
        end
    end
end

-- New function to handle furniture interaction
function Inputs:handleFurnitureInteraction()
    print("Furniture interaction triggered!")

    -- Get the player's position
    local playerX = self.game.player.x
    local playerY = self.game.player.y
    print("Player position:", playerX, playerY)

    -- Define interaction radius (how close the player needs to be to interact)
    local interactionRadius = self.game.world.tileSize * 4  -- Increased from 2 to 4 tiles
    print("Interaction radius:", interactionRadius)

    -- Check all grid positions around the player
    local playerGridX = math.floor(playerX / self.game.world.tileSize) + 1
    local playerGridY = math.floor(playerY / self.game.world.tileSize) + 1
    print("Player grid position:", playerGridX, playerGridY)

    -- Check in a 3x3 area around the player
    for y = playerGridY - 1, playerGridY + 1 do
        for x = playerGridX - 1, playerGridX + 1 do
            -- Check if this position is in grid bounds
            if x >= 1 and x <= self.game.world.width and y >= 1 and y <= self.game.world.height then
                -- Check if there's furniture at this position
                local furnitureData, state = self.game.world:getFurnitureAt(x, y)
                if furnitureData then
                    print("Found furniture at:", x, y, "State:", state)

                    -- Get the furniture type and origin
                    local furnitureType = furnitureData.type
                    local originX = furnitureData.originX
                    local originY = furnitureData.originY
                    print("Furniture type:", furnitureType, "Origin:", originX, originY)

                    -- Check if the furniture is interactable
                    local isInteractable = self.game.world.furnitureRegistry:isInteractable(furnitureType)
                    print("Is interactable:", isInteractable)

                    if isInteractable then
                        -- Calculate distance to check if player is close enough
                        local furnitureWorldX = (originX - 1) * self.game.world.tileSize
                        local furnitureWorldY = (originY - 1) * self.game.world.tileSize
                        local distance = math.sqrt((playerX - furnitureWorldX) ^ 2 + (playerY - furnitureWorldY) ^ 2)
                        print("Distance to furniture:", distance, "Max allowed:", interactionRadius)

                        if distance <= interactionRadius then
                            -- Toggle furniture state based on furniture type
                            if furnitureType == self.game.world.furnitureRegistry.FURNITURE_DOOR then
                                print("Toggling door state from", state)
                                -- Toggle door state between open and closed
                                local newState = (state == "closed") and "open" or "closed"
                                local success = self.game.world:setFurnitureState(originX, originY, newState)
                                print("Door state changed to", newState, "Success:", success)

                                -- Show notification
                                self.game.player:showNotification("Door " .. newState, {1, 1, 0.5, 1})
                                return true
                            end

                            -- Add other furniture type interactions here as needed
                        end
                    end
                end
            end
        end
    end

    print("No interactable furniture found nearby")
    return false
end

-- Handle key press events
function Inputs:keypressed(key)
    if key == "escape" then
        self.game.paused = not self.game.paused
    elseif key == "p" then
        -- Debug menu
        self.game.showDebug = not self.game.showDebug
    elseif key == "f3" then
        -- Toggle debug overlay
        self.game.showDebugOverlay = not self.game.showDebugOverlay
    elseif key == "x" then
        -- Cycle through debug pages: 0 (off) -> 1 (sprite page 1) -> 2 (sprite page 2) -> 3 (game stats) -> 0 (off)
        self.game.debugPage = (self.game.debugPage + 1) % 4
        -- For backward compatibility
        self.game.showSpriteDebug = self.game.debugPage > 0
    elseif key == "e" then
        -- Handle furniture interaction
        self:handleFurnitureInteraction()
    elseif key == "f5" then
        -- Save world
        self.game:saveWorld()
    elseif key == "f9" then
        -- Load world
        self.game:loadWorld()
    elseif key == "tab" then
        -- Toggle between block mode and furniture mode
        self.game.player:toggleFurnitureMode()

        -- Update furniture preview if switching to furniture mode
        if self.game.player.furnitureMode then
            self:updateFurniturePreview()
        else
            self.game.world.renderer:hideFurniturePreview()
        end
    elseif key == "t" then
        -- Toggle creature team overview screen
        self.game.showTeamOverview = not self.game.showTeamOverview
    elseif key == "1" or key == "2" or key == "3" or key == "4" or
           key == "5" or key == "6" or key == "7" or key == "8" or key == "9" then
        local index = tonumber(key)
        if self.game.player.furnitureMode then
            -- Select furniture by number key
            self.game.player:selectFurnitureType(index)
            self:updateFurniturePreview()
        else
            -- Select block by number key
            if index <= #self.game.player.blockTypes then
                self.game.player:selectBlockType(self.game.player.blockTypes[index])
            end
        end
    else
        -- Check if the key is part of the LISA sequence
        self.game:checkLisaSequence(key)
    end

    if not self.game.paused then
        self.game.player:keypressed(key)
    end
end

-- Handle key release events
function Inputs:keyreleased(key)
    if not self.game.paused then
        self.game.player:keyreleased(key)
    end
end

-- Handle mouse press events
function Inputs:mousepressed(x, y, button)
    if self.game.paused then
        -- Check if the click is on a pause menu button when paused
        if button == 1 then -- Left mouse button
            return self.game.ui.pauseMenu:handlePauseMenuClick(x, y)
        end
        return
    end

    if button == 1 then -- Left mouse button
        -- Start removing blocks or furniture
        self.isRemovingBlock = true
        self.blockRemovalCooldown = 0

        if self.game.player.furnitureMode then
            self:handleFurnitureRemoval()
        else
            self:handleBlockRemoval()
        end
    elseif button == 2 then -- Right mouse button
        -- Start placing blocks or furniture
        self.isPlacingBlock = true
        self.blockPlacementCooldown = 0

        if self.game.player.furnitureMode then
            self:handleFurniturePlacement()
        else
            self:handleBlockPlacement()
        end
    end
end

-- Handle mouse release events
function Inputs:mousereleased(x, y, button)
    if button == 1 then -- Left mouse button
        -- Stop removing blocks/furniture
        self.isRemovingBlock = false
    elseif button == 2 then -- Right mouse button
        -- Stop placing blocks/furniture
        self.isPlacingBlock = false
    end
end

-- Handle mouse wheel movement
function Inputs:wheelmoved(x, y)
    if self.game.paused then return end

    if y > 0 then  -- Scroll up
        if self.game.player.furnitureMode then
            self.game.player:prevFurnitureType()
            self:updateFurniturePreview()
        else
            self.game.player:prevBlockType()
        end
    elseif y < 0 then  -- Scroll down
        if self.game.player.furnitureMode then
            self.game.player:nextFurnitureType()
            self:updateFurniturePreview()
        else
            self.game.player:nextBlockType()
        end
    end
end

return Inputs
