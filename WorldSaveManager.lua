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
    -- Create a table with all the data we want to save
    local saveData = {
        width = self.gridSystem.width,
        height = self.gridSystem.height,
        worldSeed = self.worldGenerator.worldSeed,
        foregroundGrid = self.gridSystem.foregroundGrid,
        backgroundGrid = self.gridSystem.backgroundGrid
    }

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

    return true
end

-- Load a world from a saved file
function WorldSaveManager:loadWorld(filename)
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

    -- Update the grid system with loaded data
    self.gridSystem.width = saveData.width
    self.gridSystem.height = saveData.height
    self.gridSystem.foregroundGrid = saveData.foregroundGrid
    self.gridSystem.backgroundGrid = saveData.backgroundGrid

    -- Update the world generator with the saved seed
    if saveData.worldSeed then
        self.worldGenerator.worldSeed = saveData.worldSeed
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