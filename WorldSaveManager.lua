-- WorldSaveManager.lua - Handles saving and loading world data
local WorldSaveManager = {}
WorldSaveManager.__index = WorldSaveManager

function WorldSaveManager:new(gridSystem, worldGenerator)
    local self = setmetatable({}, WorldSaveManager)

    self.gridSystem = gridSystem
    self.worldGenerator = worldGenerator

    return self
end

-- Save the current world state to a file
function WorldSaveManager:saveWorld(filename)
    -- Debug information
    print("Saving world state to: " .. filename)

    -- Check for player and NPCs
    local hasPlayer = self.worldGenerator.world and self.worldGenerator.world.player
    local hasNPCs = self.worldGenerator.world and self.worldGenerator.world.npcs

    print("World reference exists: " .. tostring(self.worldGenerator.world ~= nil))
    print("Player reference exists: " .. tostring(hasPlayer))
    print("NPCs reference exists: " .. tostring(hasNPCs))

    if hasPlayer then
        print("Player position: " .. self.worldGenerator.world.player.x .. ", " .. self.worldGenerator.world.player.y)
    end

    if hasNPCs then
        print("Number of NPCs: " .. #self.worldGenerator.world.npcs)
    end

    -- Create a table with all the data we want to save
    local saveData = {
        width = self.gridSystem.width,
        height = self.gridSystem.height,
        worldSeed = self.worldGenerator.worldSeed,
        foregroundGrid = self.gridSystem.foregroundGrid,
        backgroundGrid = self.gridSystem.backgroundGrid,
        -- Save player position if player object exists
        player = hasPlayer and {
            x = self.worldGenerator.world.player.x,
            y = self.worldGenerator.world.player.y
        } or nil,
        -- Save NPC positions if they exist
        npcs = {}
    }

    -- Save all NPCs if they exist
    if hasNPCs then
        for i, npc in ipairs(self.worldGenerator.world.npcs) do
            print("Saving NPC " .. i .. " at position: " .. npc.x .. ", " .. npc.y)
            table.insert(saveData.npcs, {
                type = npc.type or "unknown", -- Store NPC type for proper recreation
                x = npc.x,
                y = npc.y
            })
        end
    end

    -- Convert the table to a string
    local serialized = "return " .. self:serializeTable(saveData)

    -- Write to file
    local file, errorMsg = io.open(filename, "w")
    if not file then
        print("Error saving world: " .. (errorMsg or "unknown error"))
        return false, errorMsg
    end

    file:write(serialized)
    file:close()

    print("World saved successfully with " .. (saveData.player and "player data" or "NO player data") ..
           " and " .. #saveData.npcs .. " NPCs")

    return true
end

-- Load a world from a saved file
function WorldSaveManager:loadWorld(filename)
    -- Debug information
    print("Loading world state from: " .. filename)

    -- Check if file exists
    local file, errorMsg = io.open(filename, "r")
    if not file then
        print("Error loading world: " .. (errorMsg or "File not found"))
        return false, errorMsg
    end

    -- Read the file content
    local content = file:read("*all")
    file:close()

    -- Load the data
    local loadFunc, errorMsg = loadstring(content)
    if not loadFunc then
        print("Error parsing save file: " .. (errorMsg or "unknown error"))
        return false, errorMsg
    end

    -- Execute the function to get the data
    local saveData = loadFunc()

    print("Loaded saveData has player data: " .. tostring(saveData.player ~= nil))
    print("Loaded saveData has " .. #saveData.npcs .. " NPCs")

    -- Update the grid system with loaded data
    self.gridSystem.width = saveData.width
    self.gridSystem.height = saveData.height
    self.gridSystem.foregroundGrid = saveData.foregroundGrid
    self.gridSystem.backgroundGrid = saveData.backgroundGrid

    -- Update the world generator with the saved seed
    if saveData.worldSeed then
        self.worldGenerator.worldSeed = saveData.worldSeed
    end

    -- Check for world reference when loading
    print("World reference exists during load: " .. tostring(self.worldGenerator.world ~= nil))

    -- Restore player position if saved and the world has a player
    if saveData.player and self.worldGenerator.world and self.worldGenerator.world.player then
        print("Restoring player to position: " .. saveData.player.x .. ", " .. saveData.player.y)
        self.worldGenerator.world.player.x = saveData.player.x
        self.worldGenerator.world.player.y = saveData.player.y
    else
        print("Could not restore player position")
        if not saveData.player then print("- No player data in save file") end
        if not self.worldGenerator.world then print("- No world reference in generator") end
        if self.worldGenerator.world and not self.worldGenerator.world.player then
            print("- No player reference in world")
        end
    end

    -- Restore NPCs if saved
    if saveData.npcs and self.worldGenerator.world then
        -- Clear existing NPCs
        if self.worldGenerator.world.npcs then
            print("Clearing " .. #self.worldGenerator.world.npcs .. " existing NPCs")
            self.worldGenerator.world.npcs = {}
        else
            print("Creating new NPCs table")
            self.worldGenerator.world.npcs = {}
        end

        -- Recreate NPCs from saved data
        for i, npcData in ipairs(saveData.npcs) do
            print("Restoring NPC " .. i .. " to position: " .. npcData.x .. ", " .. npcData.y)

            -- If you have specific NPC types with different constructors,
            -- you'll need to handle them here based on npcData.type
            -- For now, we'll assume a generic NPC creation function
            local Chicken = require("npc.chicken")
            if npcData.type and npcData.type ~= "unknown" then
                -- For future expansion: Create different NPC types based on saved type
                -- Example: local NewNPC = require("npc." .. npcData.type)
            end

            -- Create a new chicken NPC (or other type once you implement it)
            local npc = Chicken:new(self.worldGenerator.world, npcData.x, npcData.y)
            table.insert(self.worldGenerator.world.npcs, npc)
        end

        print("Restored " .. #self.worldGenerator.world.npcs .. " NPCs")
    else
        print("Could not restore NPCs")
        if not saveData.npcs then print("- No NPCs data in save file") end
        if not self.worldGenerator.world then print("- No world reference in generator") end
    end

    return true
end

-- Helper function to serialize a table to a string
function WorldSaveManager:serializeTable(tbl, indent)
    if not indent then indent = 0 end
    local result = "{\n"

    for k, v in pairs(tbl) do
        -- Indent for readability
        result = result .. string.rep("  ", indent + 1)

        -- Handle the key
        if type(k) == "number" then
            result = result .. "[" .. k .. "] = "
        elseif type(k) == "string" then
            result = result .. "[\"" .. k .. "\"] = "
        else
            result = result .. "[" .. tostring(k) .. "] = "
        end

        -- Handle the value
        if type(v) == "table" then
            result = result .. self:serializeTable(v, indent + 1)
        elseif type(v) == "string" then
            result = result .. "\"" .. v .. "\""
        else
            result = result .. tostring(v)
        end

        result = result .. ",\n"
    end

    -- Close the table
    result = result .. string.rep("  ", indent) .. "}"

    return result
end

return WorldSaveManager