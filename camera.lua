-- Camera module that handles scrolling and view transformations
local Camera = {}
Camera.__index = Camera

function Camera:new(screenWidth, screenHeight, scale)
    local self = setmetatable({}, Camera)

    self.x = 0
    self.y = 0
    self.scale = scale or 1
    self.screenWidth = screenWidth
    self.screenHeight = screenHeight
    self.target = nil
    self.smoothing = 0.1 -- Camera smoothing factor (0 to 1)

    return self
end

function Camera:follow(target)
    self.target = target
end

function Camera:update(dt)
    if self.target then
        -- Calculate the desired camera position (centered on target)
        local desiredX = self.target.x - self.screenWidth / 2 / self.scale
        local desiredY = self.target.y - self.screenHeight / 2 / self.scale

        -- Smoothly move the camera toward the target
        self.x = self.x + (desiredX - self.x) * self.smoothing * 60 * dt
        self.y = self.y + (desiredY - self.y) * self.smoothing * 60 * dt
    end
end

function Camera:set()
    -- Apply camera transformation
    love.graphics.push()
    love.graphics.scale(self.scale)
    love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:unset()
    -- Revert camera transformation
    love.graphics.pop()
end

function Camera:screenToWorld(screenX, screenY)
    -- Convert screen coordinates to world coordinates
    local worldX = screenX / self.scale + self.x
    local worldY = screenY / self.scale + self.y
    return worldX, worldY
end

function Camera:worldToScreen(worldX, worldY)
    -- Convert world coordinates to screen coordinates
    local screenX = (worldX - self.x) * self.scale
    local screenY = (worldY - self.y) * self.scale
    return screenX, screenY
end

function Camera:getBounds()
    -- Get the visible area bounds in world coordinates
    local x1 = self.x
    local y1 = self.y
    local x2 = self.x + self.screenWidth / self.scale
    local y2 = self.y + self.screenHeight / self.scale

    return x1, y1, x2, y2
end

return Camera