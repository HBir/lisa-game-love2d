-- PlayerCreatureTeam class for managing the player's team of creatures
local PlayerCreatureTeam = {}
PlayerCreatureTeam.__index = PlayerCreatureTeam

function PlayerCreatureTeam:new(world, player)
    local self = setmetatable({}, self)

    -- Team properties
    self.maxTeamSize = 6
    self.creatures = {}  -- Array of creature instances
    self.activeCreatureIndex = 1

    -- References to game world and player
    self.world = world
    self.player = player

    -- Storage for additional creatures beyond the team limit
    self.storage = {}

    -- Flag to control if creatures follow the player in overworld
    self.creaturesFollowPlayer = true

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

        -- If the creature has an overworld entity, remove it or disable it
        if creature.overworldEntity then
            creature.overworldEntity.active = false
        end

        return false, "Team is full. Creature added to storage."
    else
        -- Add to active team
        table.insert(self.creatures, creature)

        -- If this is the first creature, make it active
        if #self.creatures == 1 then
            self.activeCreatureIndex = 1
        end

        -- Create or update overworld entity if not already present
        -- self:updateCreatureOverworldEntity(creature, #self.creatures)

        return true
    end
end

-- Create or update an overworld entity for a creature
function PlayerCreatureTeam:updateCreatureOverworldEntity(creature, teamIndex)
    -- Skip if world reference isn't available
    if not self.world or not self.player then return end

    -- If creature already has an overworld entity, update it
    if creature.overworldEntity then
        creature.overworldEntity.isPlayerOwned = true
        creature.overworldEntity.followPlayer = self.creaturesFollowPlayer
        creature.overworldEntity.followIndex = teamIndex
        creature.overworldEntity.active = true
    else
        -- Find a position near the player
        local spawnX = self.player.x
        local spawnY = self.player.y

        -- Create a new overworld entity for this creature
        if self.world.creatureRegistry then
            -- Instead of creating it directly, call createCreature with full params
            local OverworldCreature = require("npc.OverworldCreature")
            local newOverworld = OverworldCreature:new(
                self.world,
                spawnX, spawnY,
                creature.id,
                creature.level
            )

            -- Set player-owned properties
            newOverworld.isPlayerOwned = true
            newOverworld.followPlayer = self.creaturesFollowPlayer
            newOverworld.followIndex = teamIndex
            newOverworld.battleCreature = creature
            creature.overworldEntity = newOverworld

            -- Add to world NPCs list
            if self.world.game and self.world.game.npcs then
                table.insert(self.world.game.npcs, newOverworld)
            end
        end
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

    -- Handle the overworld entity
    if creature.overworldEntity then
        creature.overworldEntity.followPlayer = false
        creature.overworldEntity.isPlayerOwned = false

        -- Optional: remove from world
        if self.world.game and self.world.game.npcs then
            for i, npc in ipairs(self.world.game.npcs) do
                if npc == creature.overworldEntity then
                    table.remove(self.world.game.npcs, i)
                    break
                end
            end
        end
    end

    -- Adjust active creature index if needed
    if index <= self.activeCreatureIndex then
        self.activeCreatureIndex = math.max(1, self.activeCreatureIndex - 1)
    end

    -- If the team is now empty, reset active index
    if #self.creatures == 0 then
        self.activeCreatureIndex = 0
    end

    -- Update follow indices for remaining creatures
    self:updateFollowIndices()

    return true, creature
end

-- Update follow indices for all creatures
function PlayerCreatureTeam:updateFollowIndices()
    for i, creature in ipairs(self.creatures) do
        if creature.overworldEntity then
            creature.overworldEntity.followIndex = i
        end
    end
end

-- Switch the active creature to a different index
function PlayerCreatureTeam:switchActiveCreature(index)
    if index < 1 or index > #self.creatures then
        return false, "Invalid creature index."
    end

    self.activeCreatureIndex = index

    -- Optional: Move the active creature's overworld entity to the front of the follow chain
    -- by setting lower follow indices
    self:updateFollowIndices()

    return true
end

-- Toggle whether creatures follow player in overworld
function PlayerCreatureTeam:toggleFollowingCreatures()
    self.creaturesFollowPlayer = not self.creaturesFollowPlayer

    -- Update all overworld entities
    for i, creature in ipairs(self.creatures) do
        if creature.overworldEntity then
            creature.overworldEntity.followPlayer = self.creaturesFollowPlayer
        end
    end

    return self.creaturesFollowPlayer
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
    local teamCreature = self.creatures[teamIndex]
    local storageCreature = self.storage[storageIndex]

    self.creatures[teamIndex] = storageCreature
    self.storage[storageIndex] = teamCreature

    -- Update overworld entities
    if teamCreature.overworldEntity then
        teamCreature.overworldEntity.followPlayer = false
        teamCreature.overworldEntity.active = false
    end

    -- Create/update overworld entity for the creature joining the team
    self:updateCreatureOverworldEntity(storageCreature, teamIndex)

    -- Update follow indices
    self:updateFollowIndices()

    return true
end

-- Set world and player references
function PlayerCreatureTeam:setWorldAndPlayer(world, player)
    self.world = world
    self.player = player

    -- Update all creatures' overworld entities
    for i, creature in ipairs(self.creatures) do
        self:updateCreatureOverworldEntity(creature, i)
    end
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
        print("Loading creature: " .. creatureData.id)
        local creature = creatureRegistry:createCreature(creatureData.id, creatureData.level, self.world, self.player.x, true)

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