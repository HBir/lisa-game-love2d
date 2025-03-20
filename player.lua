-- Player module that manages the princess character's behavior and controls
local Player = {}
Player.__index = Player

function Player:new(world, x, y)
    local self = setmetatable({}, Player)

    -- World reference
    self.world = world

    -- Position and size
    self.x = x
    self.y = y
    self.width = 24
    self.height = 48

    -- Movement properties
    self.speed = 120
    self.gravity = 800
    self.jumpForce = 300
    self.vx = 0
    self.vy = 0
    self.onGround = false
    self.facing = "right"

    -- Building
    self.selectedBlockType = world.BLOCK_DIRT
    self.blockTypes = {
        world.BLOCK_DIRT,
        world.BLOCK_GRASS,
        world.BLOCK_STONE,
        world.BLOCK_WOOD,
        world.BLOCK_LEAVES
    }
    self.blockTypeIndex = 1

    -- Block selection feedback
    self.blockChangeNotification = {
        text = "",
        timer = 0,
        duration = 1.5 -- How long to show the notification
    }

    -- Controls
    self.controls = {
        left = {"left", "a"},
        right = {"right", "d"},
        jump = {"up", "w", "space"},
    }

    -- Input state
    self.input = {
        left = false,
        right = false,
        jump = false,
        jumpPressed = false
    }

    -- Animation state
    self.animation = {
        state = "idle", -- idle, run, jump, fall
        frame = 1,
        timer = 0,
        frameTime = 0.1
    }

    -- Load images (placeholder, will use actual princess sprites later)
    self.images = {
        idle = love.graphics.newCanvas(self.width, self.height)
    }

    -- Draw a simple princess silhouette on canvas
    love.graphics.setCanvas(self.images.idle)
    love.graphics.clear()

    -- Set up a simple placeholder drawing
    -- Head
    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.circle("fill", self.width/2, self.height/5, self.width/3)

    -- Dress/body
    love.graphics.setColor(1, 0.4, 0.8)
    love.graphics.polygon("fill",
        self.width/2, self.height/3,
        0, self.height,
        self.width, self.height)

    -- Face
    love.graphics.setColor(0, 0, 0)
    love.graphics.points(self.width/2 - 2, self.height/5 - 1) -- left eye
    love.graphics.points(self.width/2 + 2, self.height/5 - 1) -- right eye
    love.graphics.line(self.width/2 - 1, self.height/5 + 2, self.width/2 + 1, self.height/5 + 2) -- smile

    -- Crown
    love.graphics.setColor(1, 0.84, 0)
    love.graphics.polygon("fill",
        self.width/2 - 5, self.height/5 - 6,
        self.width/2 - 3, self.height/5 - 10,
        self.width/2, self.height/5 - 8,
        self.width/2 + 3, self.height/5 - 10,
        self.width/2 + 5, self.height/5 - 6)

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    return self
end

function Player:update(dt)
    -- Process input
    self:processInput()

    -- Apply horizontal movement
    self.vx = 0
    if self.input.left then self.vx = -self.speed end
    if self.input.right then self.vx = self.speed end

    -- Update position based on velocity
    self:move(dt)

    -- Update animation
    self:updateAnimation(dt)
end

function Player:processInput()
    -- Check jump
    if self.input.jumpPressed and self.onGround then
        self.vy = -self.jumpForce
        self.onGround = false
        self.input.jumpPressed = false
    end
end

function Player:move(dt)
    -- Apply gravity
    self.vy = self.vy + self.gravity * dt

    -- Calculate new position
    local newX = self.x + self.vx * dt
    local newY = self.y + self.vy * dt

    -- Horizontal collision detection
    if self.vx ~= 0 then
        local x = newX
        if self.vx > 0 then
            x = x + self.width / 2
            self.facing = "right"
        else
            x = x - self.width / 2
            self.facing = "left"
        end

        -- Check for collision with solid blocks
        local collisionTop = self.world:isSolid(x, self.y - self.height / 2)
        local collisionMiddle = self.world:isSolid(x, self.y)
        local collisionBottom = self.world:isSolid(x, self.y + self.height / 2)

        if collisionTop or collisionMiddle or collisionBottom then
            if self.vx > 0 then
                newX = math.floor(newX / self.world.tileSize) * self.world.tileSize
            else
                newX = math.ceil(newX / self.world.tileSize) * self.world.tileSize
            end
            self.vx = 0
        end
    end

    -- Vertical collision detection
    if self.vy ~= 0 then
        local y = newY
        if self.vy > 0 then
            y = y + self.height / 2
        else
            y = y - self.height / 2
        end

        -- Check for collision with solid blocks
        local collisionLeft = self.world:isSolid(self.x - self.width / 2, y)
        local collisionCenter = self.world:isSolid(self.x, y)
        local collisionRight = self.world:isSolid(self.x + self.width / 2, y)

        if collisionLeft or collisionCenter or collisionRight then
            if self.vy > 0 then
                newY = math.floor(newY / self.world.tileSize) * self.world.tileSize
                self.onGround = true
            else
                newY = math.ceil(newY / self.world.tileSize) * self.world.tileSize
            end
            self.vy = 0
        else
            self.onGround = false
        end
    end

    -- Update position
    self.x = newX
    self.y = newY

    -- World boundaries
    if self.x < self.width / 2 then
        self.x = self.width / 2
    elseif self.x > self.world.width * self.world.tileSize - self.width / 2 then
        self.x = self.world.width * self.world.tileSize - self.width / 2
    end

    if self.y < self.height / 2 then
        self.y = self.height / 2
        self.vy = 0
    elseif self.y > self.world.height * self.world.tileSize - self.height / 2 then
        self.y = self.world.height * self.world.tileSize - self.height / 2
        self.vy = 0
        self.onGround = true
    end
end

function Player:updateAnimation(dt)
    -- Update animation state
    if not self.onGround then
        if self.vy < 0 then
            self.animation.state = "jump"
        else
            self.animation.state = "fall"
        end
    else
        if self.vx ~= 0 then
            self.animation.state = "run"
        else
            self.animation.state = "idle"
        end
    end

    -- Update animation frame
    self.animation.timer = self.animation.timer + dt
    if self.animation.timer >= self.animation.frameTime then
        self.animation.timer = self.animation.timer - self.animation.frameTime
        self.animation.frame = self.animation.frame + 1

        -- Simple animation loop
        if self.animation.state == "run" and self.animation.frame > 4 then
            self.animation.frame = 1
        elseif self.animation.frame > 1 then
            self.animation.frame = 1
        end
    end

    -- Update block change notification timer
    if self.blockChangeNotification.timer > 0 then
        self.blockChangeNotification.timer = self.blockChangeNotification.timer - dt
    end
end

function Player:draw()
    -- Draw player sprite
    love.graphics.setColor(1, 1, 1, 1)

    -- Scale based on facing direction
    local scaleX = 1
    if self.facing == "left" then scaleX = -1 end

    -- Draw the sprite
    love.graphics.draw(
        self.images.idle,
        self.x,
        self.y,
        0,  -- rotation
        scaleX, 1,  -- scale x, y
        self.width / 2, self.height / 2  -- origin x, y
    )

    -- Draw block selection notification above player if active
    if self.blockChangeNotification.timer > 0 then
        -- Calculate alpha based on remaining time (fade out)
        local alpha = math.min(1, self.blockChangeNotification.timer / (self.blockChangeNotification.duration * 0.5))

        -- Draw text background
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        local textWidth = #self.blockChangeNotification.text * 8 -- Approximate width
        love.graphics.rectangle("fill",
            self.x - textWidth/2 - 5,
            self.y - self.height - 25,
            textWidth + 10,
            20)

        -- Draw text
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(
            self.blockChangeNotification.text,
            self.x - textWidth/2,
            self.y - self.height - 20)
    end

    -- Debug collision box
    --love.graphics.setColor(1, 0, 0, 0.5)
    --love.graphics.rectangle("line", self.x - self.width / 2, self.y - self.height / 2, self.width, self.height)
end

function Player:keypressed(key)
    -- Check controls
    for action, keys in pairs(self.controls) do
        for _, k in ipairs(keys) do
            if key == k then
                self.input[action] = true
                if action == "jump" then
                    self.input.jumpPressed = true
                end
            end
        end
    end
end

function Player:keyreleased(key)
    -- Check controls
    for action, keys in pairs(self.controls) do
        for _, k in ipairs(keys) do
            if key == k then
                self.input[action] = false
            end
        end
    end
end

function Player:selectBlockType(index)
    if index >= 1 and index <= #self.blockTypes then
        self.blockTypeIndex = index
        self.selectedBlockType = self.blockTypes[self.blockTypeIndex]

        -- Update notification with block name
        local blockName = self.world.blocks[self.selectedBlockType].name
        self.blockChangeNotification.text = "Selected: " .. blockName
        self.blockChangeNotification.timer = self.blockChangeNotification.duration
    end
end

function Player:nextBlockType()
    self.blockTypeIndex = self.blockTypeIndex + 1
    if self.blockTypeIndex > #self.blockTypes then
        self.blockTypeIndex = 1
    end
    self.selectedBlockType = self.blockTypes[self.blockTypeIndex]

    -- Update notification with block name
    local blockName = self.world.blocks[self.selectedBlockType].name
    self.blockChangeNotification.text = "Selected: " .. blockName
    self.blockChangeNotification.timer = self.blockChangeNotification.duration
end

function Player:prevBlockType()
    self.blockTypeIndex = self.blockTypeIndex - 1
    if self.blockTypeIndex < 1 then
        self.blockTypeIndex = #self.blockTypes
    end
    self.selectedBlockType = self.blockTypes[self.blockTypeIndex]

    -- Update notification with block name
    local blockName = self.world.blocks[self.selectedBlockType].name
    self.blockChangeNotification.text = "Selected: " .. blockName
    self.blockChangeNotification.timer = self.blockChangeNotification.duration
end

return Player