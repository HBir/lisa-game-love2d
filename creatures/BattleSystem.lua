-- BattleSystem class to handle battles between creatures
local BattleSystem = {}
BattleSystem.__index = BattleSystem

function BattleSystem:new(playerTeam, game)
    local self = setmetatable({}, self)

    -- References
    self.playerTeam = playerTeam
    self.game = game

    -- Battle state
    self.inBattle = false
    self.enemyCreature = nil
    self.playerCreature = nil
    self.turn = "player"  -- "player" or "enemy"
    self.state = "inactive"  -- "inactive", "intro", "choosingAction", "choosingMove", "executingMove", "catching", "result"

    -- UI state
    self.selectedAction = 1  -- 1 = Fight, 2 = Catch, 3 = Switch, 4 = Run
    self.selectedMoveIndex = 1
    self.selectedCreatureIndex = 1
    self.actionOptions = {"FIGHT", "CATCH", "SWITCH", "RUN"}

    -- Animation properties
    self.animationTimer = 0
    self.messageText = ""
    self.messageTimer = 0

    -- Battle statistics
    self.turnCount = 0
    self.catchAttempts = 0

    -- Result data
    self.result = nil  -- "win", "lose", "run", "catch"

    return self
end

-- Start a battle with a wild creature
function BattleSystem:startBattle(wildCreature)
    -- Check if player has any creatures
    if #self.playerTeam.creatures == 0 then
        return false, "No creatures in team."
    end

    -- Get the player's active creature
    self.playerCreature = self.playerTeam:getActiveCreature()

    -- Check if the active creature has fainted
    if self.playerCreature.currentHp <= 0 then
        -- Find the next non-fainted creature
        local nextIndex = self.playerTeam:getNextNonFaintedCreature()
        if not nextIndex then
            return false, "All creatures have fainted."
        end

        -- Switch to the next non-fainted creature
        self.playerTeam:switchActiveCreature(nextIndex)
        self.playerCreature = self.playerTeam:getActiveCreature()
    end

    -- Set the enemy creature
    self.enemyCreature = wildCreature

    -- Initialize battle state
    self.inBattle = true
    self.state = "intro"
    self.turn = "player"
    self.turnCount = 0
    self.catchAttempts = 0
    self.result = nil

    -- Reset UI state
    self.selectedAction = 1
    self.selectedMoveIndex = 1
    self.selectedCreatureIndex = 1
    self.messageText = "A wild " .. self.enemyCreature.name .. " appeared!"
    self.messageTimer = 2  -- 2 seconds

    -- Set creatures to idle animation
    self.playerCreature:setAnimation("idle")
    self.enemyCreature:setAnimation("idle")

    -- Pause the game world
    if self.game then
        self.game.battlePaused = true
    end

    return true
end

-- Update the battle state
function BattleSystem:update(dt)
    if not self.inBattle then
        return
    end

    -- Update timers
    if self.messageTimer > 0 then
        self.messageTimer = self.messageTimer - dt
        if self.messageTimer <= 0 then
            -- Transition to next state based on current state
            if self.state == "intro" then
                self.state = "choosingAction"
            elseif self.state == "executingMove" then
                -- Reset animations back to idle
                if self.playerCreature then
                    self.playerCreature:setAnimation("idle")
                end
                if self.enemyCreature then
                    self.enemyCreature:setAnimation("idle")
                end

                -- After executing move, check for battle end
                if self:checkBattleEnd() then
                    -- Battle ended
                    self.state = "result"
                    self.messageTimer = 2  -- Show result for 2 seconds
                else
                    -- Continue battle with next turn
                    if self.turn == "player" then
                        self.turn = "enemy"
                        self:executeEnemyTurn()
                    else
                        self.turn = "player"
                        self.state = "choosingAction"
                    end
                end
            elseif self.state == "catching" then
                -- Reset animations back to idle
                if self.playerCreature then
                    self.playerCreature:setAnimation("idle")
                end

                -- After catching attempt, check if successful
                if self.result == "catch" then
                    self.state = "result"
                    self.messageTimer = 2  -- Show result for 2 seconds
                else
                    -- Continue battle with enemy turn
                    self.turn = "enemy"
                    self:executeEnemyTurn()
                end
            elseif self.state == "result" then
                -- End the battle
                self:endBattle()
            end
        end
    end

    -- Update animation
    self.animationTimer = self.animationTimer + dt

    -- Update creature animations
    if self.playerCreature then
        self.playerCreature:update(dt)
    end

    if self.enemyCreature then
        self.enemyCreature:update(dt)
    end
end

-- Handle player input during battle
function BattleSystem:handleInput(key)
    if not self.inBattle then
        return false
    end

    if self.state == "choosingAction" then
        -- Handle action selection
        if key == "up" or key == "w" then
            self.selectedAction = math.max(1, self.selectedAction - 1)
            return true
        elseif key == "down" or key == "s" then
            self.selectedAction = math.min(4, self.selectedAction + 1)
            return true
        elseif key == "return" or key == "space" then
            -- Execute selected action
            if self.selectedAction == 1 then  -- Fight
                self.state = "choosingMove"
                self.selectedMoveIndex = 1
            elseif self.selectedAction == 2 then  -- Catch
                self:attemptCatch()
            elseif self.selectedAction == 3 then  -- Switch
                if #self.playerTeam.creatures > 1 then
                    self.state = "choosingCreature"
                    self.selectedCreatureIndex = 1
                else
                    self.messageText = "No other creatures to switch to!"
                    self.messageTimer = 1.5
                end
            elseif self.selectedAction == 4 then  -- Run
                self:attemptRun()
            end
            return true
        end

    elseif self.state == "choosingMove" then
        -- Handle move selection
        if key == "up" or key == "w" then
            self.selectedMoveIndex = math.max(1, self.selectedMoveIndex - 1)
            return true
        elseif key == "down" or key == "s" then
            self.selectedMoveIndex = math.min(#self.playerCreature.moves, self.selectedMoveIndex + 1)
            return true
        elseif key == "return" or key == "space" then
            -- Execute selected move
            local move = self.playerCreature:getMove(self.selectedMoveIndex)
            if move then
                self:executePlayerMove(move)
            end
            return true
        elseif key == "escape" or key == "backspace" then
            -- Go back to action selection
            self.state = "choosingAction"
            return true
        end

    elseif self.state == "choosingCreature" then
        -- Handle creature selection
        if key == "up" or key == "w" then
            repeat
                self.selectedCreatureIndex = math.max(1, self.selectedCreatureIndex - 1)
            until self.selectedCreatureIndex == self.playerTeam.activeCreatureIndex or
                  self.playerTeam.creatures[self.selectedCreatureIndex].currentHp > 0
            return true
        elseif key == "down" or key == "s" then
            repeat
                self.selectedCreatureIndex = math.min(#self.playerTeam.creatures, self.selectedCreatureIndex + 1)
            until self.selectedCreatureIndex == self.playerTeam.activeCreatureIndex or
                  self.playerTeam.creatures[self.selectedCreatureIndex].currentHp > 0
            return true
        elseif key == "return" or key == "space" then
            -- Switch to selected creature
            if self.selectedCreatureIndex ~= self.playerTeam.activeCreatureIndex and
               self.playerTeam.creatures[self.selectedCreatureIndex].currentHp > 0 then
                self:switchCreature(self.selectedCreatureIndex)
            else
                self.messageText = "This creature is already active or has fainted!"
                self.messageTimer = 1.5
            end
            return true
        elseif key == "escape" or key == "backspace" then
            -- Go back to action selection
            self.state = "choosingAction"
            return true
        end

    elseif self.state == "result" then
        -- Skip to end of battle
        if key == "return" or key == "space" then
            self.messageTimer = 0
            return true
        end
    end

    return false
end

-- Execute player's selected move
function BattleSystem:executePlayerMove(move)
    self.state = "executingMove"

    -- Set player creature to attack animation
    self.playerCreature:setAnimation("attack")

    -- Calculate and apply damage
    local result = move:execute(self.playerCreature, self.enemyCreature)

    -- Display message
    self.messageText = self.playerCreature.name .. " used " .. move.name .. "!"
    if result.damage > 0 then
        self.messageText = self.messageText .. " Dealt " .. result.damage .. " damage!"

        -- Set enemy creature to hurt animation if damaged
        self.enemyCreature:setAnimation("hurt")
    end

    if result.fainted then
        self.messageText = self.messageText .. " " .. self.enemyCreature.name .. " fainted!"
    end

    -- Set message timer
    self.messageTimer = 2

    -- Update battle stats
    self.turnCount = self.turnCount + 1
end

-- Execute enemy's turn
function BattleSystem:executeEnemyTurn()
    -- Check if enemy can attack
    if self.enemyCreature.currentHp <= 0 then
        -- Enemy fainted, can't attack
        self.turn = "player"
        self.state = "choosingAction"
        return
    end

    self.state = "executingMove"

    -- Choose a random move for the enemy
    local moveIndex = math.random(1, #self.enemyCreature.moves)
    local move = self.enemyCreature:getMove(moveIndex)

    -- Set enemy creature to attack animation
    self.enemyCreature:setAnimation("attack")

    -- Calculate and apply damage
    local result = move:execute(self.enemyCreature, self.playerCreature)

    -- Display message
    self.messageText = self.enemyCreature.name .. " used " .. move.name .. "!"
    if result.damage > 0 then
        self.messageText = self.messageText .. " Dealt " .. result.damage .. " damage!"

        -- Set player creature to hurt animation if damaged
        self.playerCreature:setAnimation("hurt")
    end

    if result.fainted then
        self.messageText = self.messageText .. " " .. self.playerCreature.name .. " fainted!"
    end

    -- Set message timer
    self.messageTimer = 2

    -- Update battle stats
    self.turnCount = self.turnCount + 1
end

-- Attempt to catch the enemy creature
function BattleSystem:attemptCatch()
    self.state = "catching"
    self.catchAttempts = self.catchAttempts + 1

    -- Calculate catch chance based on creature's remaining HP percentage and catch attempts
    local hpPercentage = self.enemyCreature.currentHp / self.enemyCreature.stats.hp
    local baseChance = (1 - hpPercentage) * 100  -- 0% at full HP, 100% at 0 HP

    -- Increase chance slightly with each attempt
    baseChance = baseChance + (self.catchAttempts * 5)

    -- Cap chance between 10% and 90%
    local catchChance = math.max(10, math.min(90, baseChance))

    -- Roll for catch
    local roll = math.random(1, 100)
    local caught = roll <= catchChance

    if caught then
        -- Creature was caught!
        self.result = "catch"
        self.messageText = "Caught " .. self.enemyCreature.name .. "!"

        -- Add to player's team or storage
        self.playerTeam:addCreature(self.enemyCreature)
    else
        -- Failed to catch
        self.messageText = self.enemyCreature.name .. " broke free!"

        -- Have enemy creature react to the catch attempt (shake animation)
        self.enemyCreature:setAnimation("hurt")
    end

    -- Set message timer
    self.messageTimer = 2
end

-- Attempt to run from battle
function BattleSystem:attemptRun()
    -- Calculate run chance
    local runChance = 50 + (self.playerCreature.stats.speed - self.enemyCreature.stats.speed)
    runChance = math.max(25, math.min(90, runChance))  -- Clamp between 25% and 90%

    -- Increase chance with each turn
    runChance = runChance + self.turnCount * 5

    -- Roll for escape
    local roll = math.random(1, 100)
    local escaped = roll <= runChance

    if escaped then
        self.result = "run"
        self.messageText = "Got away safely!"
    else
        self.messageText = "Couldn't escape!"
        self.turn = "enemy"
    end

    -- Set message timer and update state
    self.messageTimer = 1.5
    if escaped then
        self.state = "result"
    else
        -- Enemy's turn after failed escape
        self:executeEnemyTurn()
    end
end

-- Switch to a different creature
function BattleSystem:switchCreature(index)
    -- Switch active creature
    self.playerTeam:switchActiveCreature(index)
    self.playerCreature = self.playerTeam:getActiveCreature()

    -- Display message
    self.messageText = "Switched to " .. self.playerCreature.name .. "!"

    -- Switching takes a turn, so enemy goes next
    self.turn = "enemy"
    self.state = "executingMove"
    self.messageTimer = 1.5
end

-- Check if the battle has ended
function BattleSystem:checkBattleEnd()
    -- Check if enemy fainted
    if self.enemyCreature.currentHp <= 0 then
        self.result = "win"
        self.messageText = "You won the battle!"
        return true
    end

    -- Check if player's active creature fainted
    if self.playerCreature.currentHp <= 0 then
        -- Check if player has any other non-fainted creatures
        local nextIndex = self.playerTeam:getNextNonFaintedCreature()
        if not nextIndex then
            self.result = "lose"
            self.messageText = "All your creatures have fainted!"
            return true
        else
            -- Switch to next creature
            self:switchCreature(nextIndex)
            return false
        end
    end

    -- Check for run or catch
    if self.result == "run" or self.result == "catch" then
        return true
    end

    return false
end

-- End the current battle
function BattleSystem:endBattle()
    -- Process battle results
    if self.result == "win" then
        -- Award experience
        local expGain = self.enemyCreature.level * 10
        local leveledUp = self.playerCreature:addExperience(expGain)

        -- Notify game that battle ended with victory
        if self.game then
            self.game:onBattleWon(self.enemyCreature, expGain, leveledUp)
        end

    elseif self.result == "catch" then
        -- Creature was already added to the team during catch attempt

        -- Notify game that battle ended with catch
        if self.game then
            self.game:onCreatureCaught(self.enemyCreature)
        end

    elseif self.result == "lose" then
        -- Notify game that battle was lost
        if self.game then
            self.game:onBattleLost()
        end
    end

    -- Reset battle state
    self.inBattle = false
    self.state = "inactive"
    self.enemyCreature = nil

    -- Unpause the game world
    if self.game then
        self.game.battlePaused = false
    end
end

-- Draw the battle UI
function BattleSystem:draw()
    if not self.inBattle then
        return
    end

    local width, height = love.graphics.getDimensions()

    -- Create a smaller battle area in the center of the screen
    local battleAreaWidth = width * 0.8
    local battleAreaHeight = height * 0.7
    local battleX = (width - battleAreaWidth) / 2
    local battleY = (height - battleAreaHeight) / 2

    -- Draw semi-transparent battle background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", battleX, battleY, battleAreaWidth, battleAreaHeight, 15, 15)

    -- Draw decorative border
    love.graphics.setColor(0.3, 0.3, 0.6, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", battleX, battleY, battleAreaWidth, battleAreaHeight, 15, 15)
    love.graphics.setLineWidth(1)

    -- Draw enemy creature - positioned in top right of battle area
    if self.enemyCreature then
        local enemyX = battleX + battleAreaWidth * 0.75
        local enemyY = battleY + battleAreaHeight * 0.3
        self:drawCreature(self.enemyCreature, enemyX, enemyY, 1.8, "enemy")
    end

    -- Draw player creature - positioned in bottom left of battle area
    if self.playerCreature then
        local playerX = battleX + battleAreaWidth * 0.25
        local playerY = battleY + battleAreaHeight * 0.7
        self:drawCreature(self.playerCreature, playerX, playerY, 1.8, "player")
    end

    -- Draw UI based on current state
    if self.state == "choosingAction" then
        self:drawActionMenu(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    elseif self.state == "choosingMove" then
        self:drawMoveMenu(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    elseif self.state == "choosingCreature" then
        self:drawCreatureMenu(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    end

    -- Draw message box
    if self.messageTimer > 0 then
        self:drawMessageBox(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    end
end

-- Draw a creature at the specified position
function BattleSystem:drawCreature(creature, x, y, scale, position)
    -- Draw creature sprite or placeholder
    love.graphics.setColor(1, 1, 1, 1)
    local isPlayerCreature = (position == "player")
    creature:draw(x, y, scale, isPlayerCreature)

    -- Draw HP bar
    local hpBarWidth = 100
    local hpBarHeight = 10
    local filledWidth = (creature.currentHp / creature.stats.hp) * hpBarWidth

    -- Position HP bar above for enemy, below for player
    local hpX = x - hpBarWidth / 2
    local hpY = position == "enemy" and y - 60 or y + 40

    -- Draw HP bar background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", hpX, hpY, hpBarWidth, hpBarHeight)

    -- Draw filled portion of HP bar
    local hpColor = {0.2, 0.8, 0.2}  -- Green
    if creature.currentHp <= creature.stats.hp * 0.5 then
        hpColor = {0.8, 0.8, 0.2}  -- Yellow
    end
    if creature.currentHp <= creature.stats.hp * 0.25 then
        hpColor = {0.8, 0.2, 0.2}  -- Red
    end

    love.graphics.setColor(hpColor)
    love.graphics.rectangle("fill", hpX, hpY, filledWidth, hpBarHeight)

    -- Draw HP text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(creature.currentHp .. "/" .. creature.stats.hp, hpX + hpBarWidth + 5, hpY - 2)

    -- Draw name and level
    local nameY = position == "enemy" and y - 80 or y + 20
    love.graphics.print(creature.name .. " Lv." .. creature.level, x - 50, nameY)
end

-- Draw the action selection menu
function BattleSystem:drawActionMenu(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    -- Draw menu background
    local menuWidth = battleAreaWidth * 0.35
    local menuHeight = battleAreaHeight * 0.25
    local menuX = battleX + battleAreaWidth - menuWidth - 20
    local menuY = battleY + battleAreaHeight - menuHeight - 20

    love.graphics.setColor(0.2, 0.2, 0.4, 0.9)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, 10, 10)

    -- Draw action options
    for i, action in ipairs(self.actionOptions) do
        if i == self.selectedAction then
            love.graphics.setColor(1, 1, 0, 1)  -- Highlight selected action
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        love.graphics.print(action, menuX + 15, menuY + 10 + (i - 1) * 25)
    end
end

-- Draw the move selection menu
function BattleSystem:drawMoveMenu(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    -- Draw menu background
    local menuWidth = battleAreaWidth * 0.9
    local menuHeight = battleAreaHeight * 0.25
    local menuX = battleX + (battleAreaWidth - menuWidth) / 2
    local menuY = battleY + battleAreaHeight - menuHeight - 10

    love.graphics.setColor(0.2, 0.2, 0.4, 0.9)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, 10, 10)

    -- Draw move options
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("MOVES:", menuX + 15, menuY + 10)

    for i, move in ipairs(self.playerCreature.moves) do
        if i == self.selectedMoveIndex then
            love.graphics.setColor(1, 1, 0, 1)  -- Highlight selected move
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- Draw move name and power
        love.graphics.print(move.name, menuX + 20, menuY + 35 + (i - 1) * 25)
        love.graphics.print("Power: " .. move.power, menuX + menuWidth * 0.4, menuY + 35 + (i - 1) * 25)
        love.graphics.print("Type: " .. move.type, menuX + menuWidth * 0.7, menuY + 35 + (i - 1) * 25)
    end

    -- Draw instruction to go back
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Press ESC to go back", menuX + menuWidth * 0.7, menuY + menuHeight - 20)
end

-- Draw the creature selection menu
function BattleSystem:drawCreatureMenu(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    -- Draw menu background
    local menuWidth = battleAreaWidth * 0.9
    local menuHeight = battleAreaHeight * 0.35
    local menuX = battleX + (battleAreaWidth - menuWidth) / 2
    local menuY = battleY + battleAreaHeight - menuHeight - 10

    love.graphics.setColor(0.2, 0.2, 0.4, 0.9)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, 10, 10)

    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SWITCH CREATURE:", menuX + 15, menuY + 10)

    -- Draw creature options
    for i, creature in ipairs(self.playerTeam.creatures) do
        -- Skip the active creature
        if i == self.playerTeam.activeCreatureIndex then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)  -- Gray out active creature
        elseif creature.currentHp <= 0 then
            love.graphics.setColor(0.5, 0.2, 0.2, 1)  -- Red for fainted creatures
        elseif i == self.selectedCreatureIndex then
            love.graphics.setColor(1, 1, 0, 1)  -- Highlight selected creature
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- Draw creature info
        local y = menuY + 40 + (i - 1) * 25
        love.graphics.print(creature.name .. " Lv." .. creature.level, menuX + 20, y)

        -- Draw HP
        local hpText = creature.currentHp .. "/" .. creature.stats.hp .. " HP"
        love.graphics.print(hpText, menuX + menuWidth * 0.4, y)

        -- Draw status
        local status = "Normal"
        if creature.currentHp <= 0 then
            status = "Fainted"
        elseif i == self.playerTeam.activeCreatureIndex then
            status = "Active"
        end
        love.graphics.print(status, menuX + menuWidth * 0.7, y)
    end

    -- Draw instruction to go back
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Press ESC to go back", menuX + menuWidth * 0.7, menuY + menuHeight - 20)
end

-- Draw message box
function BattleSystem:drawMessageBox(width, height, battleX, battleY, battleAreaWidth, battleAreaHeight)
    -- Draw message background at the top of the battle area
    local messageBoxWidth = battleAreaWidth * 0.9
    local messageBoxHeight = battleAreaHeight * 0.15
    local messageBoxX = battleX + (battleAreaWidth - messageBoxWidth) / 2
    local messageBoxY = battleY + 10

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", messageBoxX, messageBoxY, messageBoxWidth, messageBoxHeight, 10, 10)

    -- Draw message text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.messageText, messageBoxX + 15, messageBoxY + messageBoxHeight/2 - 10)
end

return BattleSystem