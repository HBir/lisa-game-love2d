-- BattleUI class to render creature battle interface
local BattleUI = {}
BattleUI.__index = BattleUI

function BattleUI:new(game)
    local self = setmetatable({}, self)

    -- Store reference to game
    self.game = game

    -- Battle background image
    self.battleBackground = nil
    self:loadAssets()

    return self
end

-- Load UI assets
function BattleUI:loadAssets()
    -- You can replace this with an actual battle background
    -- self.battleBackground = love.graphics.newImage("assets/UI/battle_background.png")
end

-- Draw the battle UI
function BattleUI:draw()
    if not self.game.battleSystem or not self.game.battleSystem.inBattle then
        return
    end

    -- Let the battle system handle the drawing
    self.game.battleSystem:draw()
end

-- Draw the team overview UI
function BattleUI:drawTeamOverview()
    -- Only draw if we have a creature team
    if not self.game.player.creatureTeam then
        return
    end

    local width, height = love.graphics.getDimensions()

    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("CREATURE TEAM", width * 0.4, height * 0.05, 0, 2, 2)

    -- Get team and storage data
    local team = self.game.player.creatureTeam.creatures
    local storage = self.game.player.creatureTeam.storage
    local activeIndex = self.game.player.creatureTeam.activeCreatureIndex

    -- Draw active team section
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.print("Active Team (" .. #team .. "/" .. self.game.player.creatureTeam.maxTeamSize .. ")",
                      width * 0.1, height * 0.15, 0, 1.5, 1.5)

    -- Draw each creature in the team
    for i, creature in ipairs(team) do
        local y = height * 0.2 + (i - 1) * (height * 0.1)
        local x = width * 0.1

        -- Draw highlight for active creature
        if i == activeIndex then
            love.graphics.setColor(0.3, 0.3, 0.5, 0.5)
            love.graphics.rectangle("fill", x - 10, y - 5, width * 0.35, height * 0.09, 5, 5)
        end

        -- Draw creature info
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(creature.name .. " (Lv. " .. creature.level .. ")", x, y)

        -- Draw HP bar
        local hpBarWidth = 150
        local hpBarHeight = 10
        local filledWidth = (creature.currentHp / creature.stats.hp) * hpBarWidth

        -- Draw HP bar background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", x, y + 20, hpBarWidth, hpBarHeight)

        -- Draw filled portion of HP bar
        local hpColor = {0.2, 0.8, 0.2}  -- Green
        if creature.currentHp <= creature.stats.hp * 0.5 then
            hpColor = {0.8, 0.8, 0.2}  -- Yellow
        end
        if creature.currentHp <= creature.stats.hp * 0.25 then
            hpColor = {0.8, 0.2, 0.2}  -- Red
        end

        love.graphics.setColor(hpColor)
        love.graphics.rectangle("fill", x, y + 20, filledWidth, hpBarHeight)

        -- Draw HP text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(creature.currentHp .. "/" .. creature.stats.hp .. " HP", x + hpBarWidth + 10, y + 18)

        -- Draw stats
        love.graphics.print("ATK: " .. creature.stats.attack, x + 250, y)
        love.graphics.print("SPD: " .. creature.stats.speed, x + 350, y)

        -- Draw exp progress
        love.graphics.print("EXP: " .. creature.experience .. "/" .. creature.experienceToNextLevel, x, y + 35)
    end

    -- Draw storage section if there are creatures in storage
    if #storage > 0 then
        love.graphics.setColor(0.8, 0.8, 1, 1)
        love.graphics.print("Storage (" .. #storage .. " creatures)",
                          width * 0.6, height * 0.15, 0, 1.5, 1.5)

        -- Draw storage creatures (simplified view)
        local columns = 3
        local itemWidth = width * 0.1
        local itemHeight = height * 0.08
        local startX = width * 0.6
        local startY = height * 0.2

        for i, creature in ipairs(storage) do
            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            local x = startX + col * (itemWidth + 20)
            local y = startY + row * (itemHeight + 10)

            -- Draw creature info box
            love.graphics.setColor(0.2, 0.2, 0.4, 0.5)
            love.graphics.rectangle("fill", x, y, itemWidth, itemHeight, 5, 5)

            -- Draw creature info
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(creature.name, x + 5, y + 5)
            love.graphics.print("Lv. " .. creature.level, x + 5, y + 20)
            love.graphics.print("HP: " .. creature.currentHp .. "/" .. creature.stats.hp, x + 5, y + 35)
        end
    end

    -- Draw instructions
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Press ESC to return to game", width * 0.4, height * 0.95)
end

-- Update function (for animations, etc.)
function BattleUI:update(dt)
    -- Handle any UI-specific updates here
end

return BattleUI