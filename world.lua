-- World module that manages the block grid and terrain generation
local Block = require("block")

local World = {}
World.__index = World

-- Block types
World.BLOCK_AIR = 0
World.BLOCK_DIRT = 1
World.BLOCK_GRASS = 2
World.BLOCK_STONE = 3
World.BLOCK_WOOD = 4
World.BLOCK_LEAVES = 5

function World:new(width, height, tileSize)
    local self = setmetatable({}, World)

    self.width = width
    self.height = height
    self.tileSize = tileSize

    -- Initialize the grid
    self.grid = {}
    for y = 1, height do
        self.grid[y] = {}
        for x = 1, width do
            self.grid[y][x] = World.BLOCK_AIR
        end
    end

    -- Block definitions
    self.blocks = {
        [World.BLOCK_AIR] = { name = "Air", color = {0, 0, 0, 0}, solid = false },
        [World.BLOCK_DIRT] = { name = "Dirt", color = {0.6, 0.4, 0.2, 1}, solid = true },
        [World.BLOCK_GRASS] = { name = "Grass", color = {0.2, 0.8, 0.2, 1}, solid = true },
        [World.BLOCK_STONE] = { name = "Stone", color = {0.5, 0.5, 0.5, 1}, solid = true },
        [World.BLOCK_WOOD] = { name = "Wood", color = {0.6, 0.3, 0.1, 1}, solid = true },
        [World.BLOCK_LEAVES] = { name = "Leaves", color = {0.1, 0.6, 0.1, 1}, solid = false },
    }

    -- Block images will be loaded here
    self.blockImages = {}

    return self
end

function World:generate()
    -- Simple terrain generation
    local groundHeight = math.floor(self.height * 0.7)

    -- Generate terrain with Perlin noise
    for x = 1, self.width do
        -- Create a simple hill function
        local heightOffset = math.floor(math.sin(x / 20) * 5)
        local rockDepth = groundHeight + heightOffset + 3 -- Depth where dirt becomes stone

        -- Fill ground
        for y = groundHeight + heightOffset, self.height do
            if y == groundHeight + heightOffset then
                self:setBlock(x, y, World.BLOCK_GRASS)
            elseif y < rockDepth then
                self:setBlock(x, y, World.BLOCK_DIRT)
            else
                self:setBlock(x, y, World.BLOCK_STONE)
            end
        end

        -- Randomly place trees
        if math.random() < 0.05 then
            self:generateTree(x, groundHeight + heightOffset - 1)
        end
    end
end

function World:generateTree(x, y)
    -- Tree trunk
    local treeHeight = math.random(4, 6)
    for i = 1, treeHeight do
        self:setBlock(x, y - i, World.BLOCK_WOOD)
    end

    -- Tree leaves
    local leafSize = 2
    for ly = y - treeHeight - leafSize, y - treeHeight + leafSize do
        for lx = x - leafSize, x + leafSize do
            -- Don't overwrite existing blocks and stay in bounds
            if lx >= 1 and lx <= self.width and ly >= 1 and ly <= self.height then
                if self:getBlock(lx, ly) == World.BLOCK_AIR then
                    self:setBlock(lx, ly, World.BLOCK_LEAVES)
                end
            end
        end
    end
end

function World:getBlock(x, y)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        return self.grid[gridY][gridX]
    end

    -- Default to air for out of bounds
    return World.BLOCK_AIR
end

function World:getBlockAt(gridX, gridY)
    -- Direct grid access with bounds checking
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        return self.grid[gridY][gridX]
    end
    return World.BLOCK_AIR
end

function World:setBlock(x, y, blockType)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x)
    local gridY = math.floor(y)

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        self.grid[gridY][gridX] = blockType
    end
end

function World:placeBlock(x, y, blockType)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds and the spot is empty (air)
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height and
       self.grid[gridY][gridX] == World.BLOCK_AIR then
        self.grid[gridY][gridX] = blockType
        return true
    end

    return false
end

function World:removeBlock(x, y)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds and the spot is not air
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height and
       self.grid[gridY][gridX] ~= World.BLOCK_AIR then
        self.grid[gridY][gridX] = World.BLOCK_AIR
        return true
    end

    return false
end

function World:draw(camera)
    -- Get visible area bounds in tiles
    local x1, y1, x2, y2 = camera:getBounds()

    -- Convert to grid indices
    local startX = math.max(1, math.floor(x1 / self.tileSize) + 1)
    local startY = math.max(1, math.floor(y1 / self.tileSize) + 1)
    local endX = math.min(self.width, math.floor(x2 / self.tileSize) + 1)
    local endY = math.min(self.height, math.floor(y2 / self.tileSize) + 1)

    -- Draw visible blocks
    for y = startY, endY do
        for x = startX, endX do
            local blockType = self.grid[y][x]

            -- Skip air blocks
            if blockType ~= World.BLOCK_AIR then
                -- Set block color
                local block = self.blocks[blockType]
                love.graphics.setColor(block.color)

                -- Calculate position
                local pixelX = (x - 1) * self.tileSize
                local pixelY = (y - 1) * self.tileSize

                -- Draw block
                love.graphics.rectangle("fill", pixelX, pixelY, self.tileSize, self.tileSize)

                -- Draw outline
                love.graphics.setColor(0, 0, 0, 0.3)
                love.graphics.rectangle("line", pixelX, pixelY, self.tileSize, self.tileSize)
            end
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function World:isSolid(x, y)
    local blockType = self:getBlock(x, y)
    return self.blocks[blockType] and self.blocks[blockType].solid
end

return World