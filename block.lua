-- Block module that defines block properties
local Block = {}
Block.__index = Block

function Block:new(id, name, color, solid)
    local self = setmetatable({}, Block)

    self.id = id
    self.name = name
    self.color = color
    self.solid = solid or true
    self.image = nil -- Will hold block texture if loaded

    return self
end

function Block:loadImage(path)
    if path then
        self.image = love.graphics.newImage(path)
    end
end

function Block:draw(x, y, size)
    if self.image then
        -- Draw with image if available
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.image, x, y, 0, size / self.image:getWidth(), size / self.image:getHeight())
    else
        -- Draw with color if no image
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", x, y, size, size)

        -- Draw border
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("line", x, y, size, size)
    end
end

return Block