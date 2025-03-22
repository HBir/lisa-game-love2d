-- FurnitureRegistry.lua - Handles furniture definitions and sprite loading
local FurnitureRegistry = {}
FurnitureRegistry.__index = FurnitureRegistry

-- Furniture type constants
FurnitureRegistry.FURNITURE_DOOR = 1
FurnitureRegistry.FURNITURE_BED = 2
FurnitureRegistry.FURNITURE_CHAIR = 3
FurnitureRegistry.FURNITURE_TABLE = 4
FurnitureRegistry.FURNITURE_BOOKSHELF = 5
FurnitureRegistry.FURNITURE_SOFA = 6
FurnitureRegistry.FURNITURE_SMALL_TABLE = 7

function FurnitureRegistry:new()
    local self = setmetatable({}, FurnitureRegistry)

    -- Load furniture sprite sheet
    self.spriteSheet = love.graphics.newImage("assets/Objects/furniture.png")
    self.spriteSheet:setFilter("nearest", "nearest")

    -- Parse CSS file to get sprite positions
    self.cssData = self:parseCSSFile("assets/Objects/furniture.css")

    -- Initialize furniture definitions
    self.furniture = self:initializeFurnitureDefinitions()

    -- Create quads for each furniture type
    self.furnitureQuads = self:createQuads()

    return self
end

-- Parse the CSS file to extract sprite coordinates
function FurnitureRegistry:parseCSSFile(filePath)
    local cssData = {}
    local file = io.open(filePath, "r")

    if not file then
        print("Warning: Could not open furniture CSS file")
        return cssData
    end

    local currentClass = nil

    for line in file:lines() do
        -- Find class name
        local className = line:match("%.([%w%-]+)%s*{")
        if className then
            currentClass = className
            cssData[currentClass] = {}
        end

        -- Find background position
        if currentClass then
            -- Match format: background: url('imgs/furniture.png') no-repeat -55px -1px;
            local bgLine = line:match("background:%s*url%([^%)]+%)%s*no%-repeat%s*([^;]+)")
            if bgLine then
                local x = bgLine:match("%-(%d+)px")
                local y = bgLine:match("%-(%d+)px%s*$")

                if x and y then
                    cssData[currentClass].x = tonumber(x)
                    cssData[currentClass].y = tonumber(y)
                    print("Parsed " .. currentClass .. " x=" .. x .. ", y=" .. y)
                end
            end

            -- Find dimensions
            local width = line:match("width:%s*(%d+)px")
            local height = line:match("height:%s*(%d+)px")

            if width then
                cssData[currentClass].width = tonumber(width)
                print("  width=" .. width)
            end

            if height then
                cssData[currentClass].height = tonumber(height)
                print("  height=" .. height)
            end
        end
    end

    file:close()
    return cssData
end

function FurnitureRegistry:initializeFurnitureDefinitions()
    local furniture = {}

    -- Door (1x4 blocks, using actual sprite dimensions)
    furniture[self.FURNITURE_DOOR] = {
        name = "Door",
        width = 1,
        height = 4,
        solid = true,
        interactable = true,
        states = {
            closed = { frame = 0 },
            open = { frame = 1 }
        },
        defaultState = "closed",
        color = {0.8, 0.6, 0.4, 1},
        cssClass = "door"
    }

    -- Bookshelf
    furniture[self.FURNITURE_BOOKSHELF] = {
        name = "Bookshelf",
        width = 2,
        height = 3,
        solid = true,
        interactable = false,
        states = {
            normal = { frame = 0 }
        },
        defaultState = "normal",
        color = {0.6, 0.4, 0.2, 1},
        cssClass = "bookshelf"
    }

    -- Bed (2x1 blocks)
    furniture[self.FURNITURE_BED] = {
        name = "Bed",
        width = 4,
        height = 2,
        solid = true,
        interactable = true,
        states = {
            normal = { frame = 0 }
        },
        defaultState = "normal",
        color = {0.6, 0.3, 0.7, 1},
        cssClass = "bed-red"
    }

    -- Chair (1x1 blocks)
    furniture[self.FURNITURE_CHAIR] = {
        name = "Chair",
        width = 1,
        height = 2,
        solid = false,  -- Can walk through
        interactable = true,
        states = {
            empty = { frame = 0 }
        },
        defaultState = "empty",
        color = {0.8, 0.5, 0.3, 1},
        cssClass = "chair"
    }

    -- Table
    furniture[self.FURNITURE_TABLE] = {
        name = "Table",
        width = 3,
        height = 2,
        solid = true,
        interactable = false,
        states = {
            normal = { frame = 0 }
        },
        defaultState = "normal",
        color = {0.7, 0.5, 0.3, 1},
        cssClass = "table"
    }

    -- Sofa
    furniture[self.FURNITURE_SOFA] = {
        name = "Sofa",
        width = 4,
        height = 2,
        solid = true,
        interactable = true,
        states = {
            normal = { frame = 0 }
        },
        defaultState = "normal",
        color = {0.3, 0.5, 0.8, 1},
        cssClass = "sofa-blue"
    }

    -- Small Table
    furniture[self.FURNITURE_SMALL_TABLE] = {
        name = "Small Table",
        width = 2,
        height = 1,
        solid = true,
        interactable = false,
        states = {
            normal = { frame = 0 }
        },
        defaultState = "normal",
        color = {0.7, 0.5, 0.3, 1},
        cssClass = "small-table"
    }

    return furniture
end

function FurnitureRegistry:createQuads()
    local quads = {}

    -- Create quads for all furniture types using CSS data
    for furnitureType, furnitureData in pairs(self.furniture) do
        local cssClass = furnitureData.cssClass
        local cssInfo = self.cssData[cssClass]

        if cssInfo and cssInfo.x and cssInfo.y and cssInfo.width and cssInfo.height then
            -- Store the actual sprite dimensions
            furnitureData.spriteWidth = cssInfo.width
            furnitureData.spriteHeight = cssInfo.height

            -- Create quads for each state
            for stateName, stateData in pairs(furnitureData.states) do
                local x = cssInfo.x
                local y = cssInfo.y
                local width = cssInfo.width
                local height = cssInfo.height

                -- Apply frame offset if needed
                if stateData.frame > 0 then
                    -- For now, we're just shifting frame by the item width (can be customized later)
                    x = x + (width * stateData.frame)
                end

                local key = furnitureType .. "_" .. stateName
                quads[key] = love.graphics.newQuad(
                    x, y,
                    width, height,
                    self.spriteSheet:getWidth(),
                    self.spriteSheet:getHeight()
                )
            end
        else
            print("Warning: Missing or incomplete CSS data for " .. furnitureData.name)
            print("  CSS class: " .. (cssClass or "nil"))
            if cssInfo then
                print("  x: " .. (cssInfo.x or "nil") ..
                      ", y: " .. (cssInfo.y or "nil") ..
                      ", width: " .. (cssInfo.width or "nil") ..
                      ", height: " .. (cssInfo.height or "nil"))
            end

            -- Create a fallback quad with a solid color
            for stateName, _ in pairs(furnitureData.states) do
                local key = furnitureType .. "_" .. stateName
                -- Use a small 1x1 pixel area from the top-left of the sprite sheet
                quads[key] = love.graphics.newQuad(
                    0, 0,
                    1, 1,
                    self.spriteSheet:getWidth(),
                    self.spriteSheet:getHeight()
                )
            end
        end
    end

    return quads
end

function FurnitureRegistry:getQuad(furnitureType, state)
    local item = self.furniture[furnitureType]
    if not item then return nil end

    -- Use the specified state or default state
    local stateName = state or item.defaultState
    local key = furnitureType .. "_" .. stateName

    return self.furnitureQuads[key]
end

function FurnitureRegistry:getFurniture(furnitureType)
    return self.furniture[furnitureType]
end

function FurnitureRegistry:isSolid(furnitureType)
    local item = self.furniture[furnitureType]
    return item and item.solid
end

function FurnitureRegistry:isInteractable(furnitureType)
    local item = self.furniture[furnitureType]
    return item and item.interactable
end

function FurnitureRegistry:getDefaultState(furnitureType)
    local item = self.furniture[furnitureType]
    return item and item.defaultState
end

function FurnitureRegistry:getStates(furnitureType)
    local item = self.furniture[furnitureType]
    return item and item.states
end

function FurnitureRegistry:getDimensions(furnitureType)
    local item = self.furniture[furnitureType]
    if not item then return 1, 1 end
    return item.width, item.height
end

function FurnitureRegistry:getSpriteSize(furnitureType)
    local item = self.furniture[furnitureType]
    if not item then return 16, 16 end
    return item.spriteWidth or 16, item.spriteHeight or 16
end

-- Get all furniture types as an array
function FurnitureRegistry:getAllFurnitureTypes()
    local types = {}
    for k, v in pairs(FurnitureRegistry) do
        if type(k) == "string" and k:match("^FURNITURE_") then
            table.insert(types, v)
        end
    end
    table.sort(types)
    return types
end

-- Export the registry as a function to create instances
return function()
    local registry = FurnitureRegistry:new()

    -- Copy constants to the registry instance
    for k, v in pairs(FurnitureRegistry) do
        if type(k) == "string" and k:match("^FURNITURE_") then
            registry[k] = v
        end
    end

    return registry
end