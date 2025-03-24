-- PlayerCreatureTeam class for managing the player's team of creatures
local PlayerCreatureTeam = {}
PlayerCreatureTeam.__index = PlayerCreatureTeam

function PlayerCreatureTeam:new()
    local self = setmetatable({}, self)

    -- Team properties
    self.maxTeamSize = 6
    self.creatures = {}  -- Array of creature instances
    self.activeCreatureIndex = 1

    -- Storage for additional creatures beyond the team limit
    self.storage = {}

    return self
end

-- Get the active creature
function PlayerCreatureTeam:getActiveCreature()
    if #self.creatures == 0 then
        return nil
    end
    return self.creatures[self.activeCreatureIndex]
end

-- Add a creature to the team
function PlayerCreatureTeam:addCreature(creature)
    if #self.creatures >= self.maxTeamSize then
        -- Team is full, add to storage instead
        table.insert(self.storage, creature)
        return false, "Team is full. Creature added to storage."
    else
        -- Add to active team
        table.insert(self.creatures, creature)

        -- If this is the first creature, make it active
        if #self.creatures == 1 then
            self.activeCreatureIndex = 1
        end

        return true
    end
end

-- Remove a creature from the team by index
function PlayerCreatureTeam:removeCreature(index)
    if index < 1 or index > #self.creatures then
        return false, "Invalid creature index."
    end

    -- Get the creature to remove
    local creature = self.creatures[index]

    -- Remove from team
    table.remove(self.creatures, index)

    -- Adjust active creature index if needed
    if index <= self.activeCreatureIndex then
        self.activeCreatureIndex = math.max(1, self.activeCreatureIndex - 1)
    end

    -- If the team is now empty, reset active index
    if #self.creatures == 0 then
        self.activeCreatureIndex = 0
    end

    return true, creature
end

-- Switch the active creature to a different index
function PlayerCreatureTeam:switchActiveCreature(index)
    if index < 1 or index > #self.creatures then
        return false, "Invalid creature index."
    end

    self.activeCreatureIndex = index
    return true
end

-- Swap creatures between team and storage
function PlayerCreatureTeam:swapWithStorage(teamIndex, storageIndex)
    if teamIndex < 1 or teamIndex > #self.creatures then
        return false, "Invalid team creature index."
    end

    if storageIndex < 1 or storageIndex > #self.storage then
        return false, "Invalid storage creature index."
    end

    -- Swap the creatures
    local temp = self.creatures[teamIndex]
    self.creatures[teamIndex] = self.storage[storageIndex]
    self.storage[storageIndex] = temp

    return true
end

-- Heal all creatures in the team
function PlayerCreatureTeam:healAllCreatures()
    for _, creature in ipairs(self.creatures) do
        creature:fullHeal()
    end
end

-- Check if all creatures in the team have fainted
function PlayerCreatureTeam:isAllFainted()
    for _, creature in ipairs(self.creatures) do
        if creature.currentHp > 0 then
            return false
        end
    end
    return true
end

-- Find the next non-fainted creature in the team
function PlayerCreatureTeam:getNextNonFaintedCreature()
    if #self.creatures == 0 then
        return nil
    end

    for i, creature in ipairs(self.creatures) do
        if creature.currentHp > 0 then
            return i, creature
        end
    end

    return nil
end

-- Save team data (for game saving)
function PlayerCreatureTeam:saveData()
    local data = {
        activeIndex = self.activeCreatureIndex,
        team = {},
        storage = {}
    }

    -- Save team creatures
    for i, creature in ipairs(self.creatures) do
        data.team[i] = {
            id = creature.id,
            name = creature.name,
            level = creature.level,
            exp = creature.experience,
            currentHp = creature.currentHp,
            stats = {
                hp = creature.stats.hp,
                attack = creature.stats.attack,
                speed = creature.stats.speed
            },
            baseStats = {
                hp = creature.baseStats.hp,
                attack = creature.baseStats.attack,
                speed = creature.baseStats.speed
            },
            moves = {}
        }

        -- Save moves
        for j, move in ipairs(creature.moves) do
            data.team[i].moves[j] = {
                name = move.name,
                power = move.power,
                type = move.type
            }
        end
    end

    -- Save storage creatures (similar structure)
    for i, creature in ipairs(self.storage) do
        data.storage[i] = {
            id = creature.id,
            name = creature.name,
            level = creature.level,
            exp = creature.experience,
            currentHp = creature.currentHp,
            stats = {
                hp = creature.stats.hp,
                attack = creature.stats.attack,
                speed = creature.stats.speed
            },
            baseStats = {
                hp = creature.baseStats.hp,
                attack = creature.baseStats.attack,
                speed = creature.baseStats.speed
            },
            moves = {}
        }

        -- Save moves
        for j, move in ipairs(creature.moves) do
            data.storage[i].moves[j] = {
                name = move.name,
                power = move.power,
                type = move.type
            }
        end
    end

    return data
end

-- Load team data (for game loading)
function PlayerCreatureTeam:loadData(data, creatureRegistry)
    if not data then return false end

    -- Clear current team and storage
    self.creatures = {}
    self.storage = {}
    self.activeCreatureIndex = data.activeIndex or 1

    -- Helper function to load a creature from saved data
    local function loadCreatureFromData(creatureData)
        local creature = creatureRegistry:createCreature(creatureData.id, creatureData.level)

        -- Override defaults with saved data
        creature.name = creatureData.name
        creature.level = creatureData.level
        creature.experience = creatureData.exp
        creature.currentHp = creatureData.currentHp

        -- Override stats
        creature.stats.hp = creatureData.stats.hp
        creature.stats.attack = creatureData.stats.attack
        creature.stats.speed = creatureData.stats.speed

        creature.baseStats.hp = creatureData.baseStats.hp
        creature.baseStats.attack = creatureData.baseStats.attack
        creature.baseStats.speed = creatureData.baseStats.speed

        -- Clear default moves
        creature.moves = {}

        -- Load moves
        local Moves = require("creatures.Move")
        for _, moveData in ipairs(creatureData.moves) do
            local move = Moves.Move:new(moveData.name, moveData.power, moveData.type)
            table.insert(creature.moves, move)
        end

        return creature
    end

    -- Load team creatures
    for _, creatureData in ipairs(data.team) do
        local creature = loadCreatureFromData(creatureData)
        table.insert(self.creatures, creature)
    end

    -- Load storage creatures
    for _, creatureData in ipairs(data.storage) do
        local creature = loadCreatureFromData(creatureData)
        table.insert(self.storage, creature)
    end

    return true
end

return PlayerCreatureTeam