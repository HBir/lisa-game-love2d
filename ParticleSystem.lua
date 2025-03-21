-- Inputs module for handling all input-related functionality
local ParticleSystem = {}
ParticleSystem.__index = ParticleSystem

function ParticleSystem:new()
  local self = setmetatable({}, ParticleSystem)

  -- Initialize player reference as nil until it's set
  self.player = nil
  -- Initialize world reference as nil until it's set
  self.world = nil

  -- Initialize firework particles array
  self.fireworkParticles = {}

  -- Initialize block particles arrays
  self.activeBlockParticles = {}
  self.activePlaceParticles = {}

  -- Initialize player tracking
  self.playerTracking = {
    wasInAir = false,
    airTime = 0,
    prevVelocityY = 0,
    landingParticles = {}
  }

  -- Initialize LISA sequence
  self.lisaSequence = {
    pattern = {"l", "i", "s", "a"},
    currentIndex = 0,
    displayTimer = 0
  }


  -- Use pcall to catch any errors during initialization
  local success, err = pcall(function()
    -- Create dust particle system with fewer max particles
    self.dustParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(6, 6), 50)  -- Larger canvas, fewer max particles

    -- Draw a simple dust particle on the canvas (larger)
    love.graphics.setCanvas(self.dustParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 6, 6)  -- Larger base particle
    love.graphics.setCanvas()


    -- Configure the particle system
    self.dustParticles:setParticleLifetime(0.6, 1.3)  -- Slightly reduced lifetime for less rise
    self.dustParticles:setEmissionRate(0)  -- Start with no emission, will be set dynamically
    self.dustParticles:setSizeVariation(0.6) -- More size variation (60%)
    -- Larger initial sizes and more gradual shrinking
    self.dustParticles:setSizes(1.5, 1.3, 1.0, 0.6, 0.3)  -- Added more size steps for smoother shrinking
    self.dustParticles:setColors(
        0.95, 0.95, 0.9, 0.8,  -- Initial color (more opaque)
        0.9, 0.9, 0.85, 0.7,   -- Mid-life color
        0.85, 0.85, 0.8, 0.5,  -- Later color
        0.8, 0.8, 0.8, 0.3,    -- Near-end color
        0.8, 0.8, 0.75, 0      -- End color (fade out)
    )
    self.dustParticles:setPosition(0, 0)  -- Will be updated based on player position
    self.dustParticles:setLinearDamping(0.4) -- More damping to slow particles down faster

    -- In LÖVE, the emission direction 0 is right, π/2 is down, π is left, 3π/2 is up
    -- So for upward movement we need to use 3π/2 (or -π/2) as base direction
    self.dustParticles:setDirection(-math.pi/2)  -- Straight up
    self.dustParticles:setSpeed(8, 20)    -- REDUCED speed for gentler upward movement

    -- Linear acceleration: minX, minY, maxX, maxY
    self.dustParticles:setLinearAcceleration(-3, -25, 3, -15)  -- REDUCED upward acceleration

    self.dustParticles:setSpread(math.pi/7)  -- Slightly wider spread (25.7 degrees) for more natural dispersion
    self.dustParticles:setRelativeRotation(true)
    -- Add slight spin to particles
    self.dustParticles:setSpin(0, math.pi)  -- Reduced spin range
    self.dustParticles:setSpinVariation(1.0)

    -- Variables to control dust emission
    self.lastPlayerX = 0
    self.lastPlayerY = 0
    self.dustEmitTimer = 0
    self.burstEmitTimer = 0  -- Timer for larger, less frequent bursts

    -- Create block break particle system
    self.blockBreakParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(4, 4), 100)

    -- Draw a simple square particle on the canvas
    love.graphics.setCanvas(self.blockBreakParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 4, 4)
    love.graphics.setCanvas()

    -- Configure the block break particle system
    self.blockBreakParticles:setParticleLifetime(0.3, 0.8)
    self.blockBreakParticles:setEmissionRate(0)  -- Only emit when triggered
    self.blockBreakParticles:setSizeVariation(0.5)
    self.blockBreakParticles:setSizes(0.8, 0.6, 0.4, 0.2)
    -- Colors will be set dynamically based on the block type
    self.blockBreakParticles:setPosition(0, 0)  -- Will be set when a block is broken
    self.blockBreakParticles:setLinearDamping(0.1)

    -- Explode in all directions
    self.blockBreakParticles:setDirection(0)  -- Will spread in all directions
    self.blockBreakParticles:setSpeed(30, 80)
    self.blockBreakParticles:setSpread(math.pi * 2)  -- Full 360 degrees

    -- Add gravity effect
    self.blockBreakParticles:setLinearAcceleration(0, 100, 0, 200)

    -- Add slight rotation to particles
    self.blockBreakParticles:setSpin(-6, 6)
    self.blockBreakParticles:setSpinVariation(1.0)

    -- Create block place particle system
    self.blockPlaceParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(3, 3), 100)

    -- Draw a simple square particle on the canvas
    love.graphics.setCanvas(self.blockPlaceParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 3, 3)
    love.graphics.setCanvas()

    -- Configure the block place particle system
    self.blockPlaceParticles:setParticleLifetime(0.3, 0.6)
    self.blockPlaceParticles:setEmissionRate(0)  -- Only emit when triggered
    self.blockPlaceParticles:setSizeVariation(0.4)
    self.blockPlaceParticles:setSizes(0.6, 0.8, 0.5, 0.2)  -- Grow then shrink
    -- Colors will be set dynamically based on the block type
    self.blockPlaceParticles:setPosition(0, 0)  -- Will be set when a block is placed
    self.blockPlaceParticles:setLinearDamping(0.2)

    -- Particles rise from the block edges
    self.blockPlaceParticles:setDirection(-math.pi/2)  -- Upward
    self.blockPlaceParticles:setSpeed(5, 15)          -- Slower than break particles
    self.blockPlaceParticles:setSpread(math.pi/1.2)   -- Mostly upward with some spread

    -- Slight inward gravity to make them hover around the block
    self.blockPlaceParticles:setLinearAcceleration(-15, -10, 15, -5)

    -- Add slight rotation to particles
    self.blockPlaceParticles:setSpin(-2, 2)
    self.blockPlaceParticles:setSpinVariation(1.0)

    -- Create landing particle system
    self.landingParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(5, 5), 80)

    -- Draw a simple particle on the canvas
    love.graphics.setCanvas(self.landingParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 5, 5)
    love.graphics.setCanvas()

    -- Configure the landing particle system
    self.landingParticles:setParticleLifetime(0.2, 0.8)
    self.landingParticles:setEmissionRate(0)  -- Only emit when triggered
    self.landingParticles:setSizeVariation(0.6)
    self.landingParticles:setSizes(1.0, 1.5, 1.2, 0.7, 0.3)  -- Expand then contract
    -- Colors will be set based on terrain
    self.landingParticles:setColors(
        0.9, 0.9, 0.8, 0.7,  -- Initial color
        0.9, 0.85, 0.75, 0.8,  -- Mid-life color
        0.85, 0.8, 0.7, 0.6,  -- Later color
        0.8, 0.75, 0.7, 0.4,  -- Near-end color
        0.8, 0.75, 0.65, 0   -- End color (fade out)
    )

    -- Particles should go outward in a wide arc from the feet
    self.landingParticles:setDirection(0)  -- Will be modified at emission
    self.landingParticles:setSpread(math.pi * 0.7)  -- Wide spread but not full circle
    self.landingParticles:setSpeed(30, 70)  -- Faster for impact feeling

    -- Add effects to make them feel "impactful"
    self.landingParticles:setLinearAcceleration(-5, -20, 5, 30)  -- Slight upward then gravity
    self.landingParticles:setLinearDamping(2.0)  -- High damping to slow quickly

    -- Add slight rotation
    self.landingParticles:setSpin(-1, 1)
    self.landingParticles:setSpinVariation(1.0)

    -- Create firework particle system
    self:initFireworkParticleSystem()
  end)

  if not success then
    print("ERROR in ParticleSystem:new() - " .. tostring(err))
    return nil
  end

  return self
end

-- Initialize the firework particle system
function ParticleSystem:initFireworkParticleSystem()
  -- Base firework particle system
  self.fireworkBase = love.graphics.newParticleSystem(love.graphics.newCanvas(4, 4), 500)

  -- Draw a simple particle on the canvas
  love.graphics.setCanvas(self.fireworkBase:getTexture())
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 4, 4)
  love.graphics.setCanvas()

  -- Configure the base firework system
  self.fireworkBase:setParticleLifetime(0.5, 1.5)
  self.fireworkBase:setEmissionRate(0)  -- Only emit when triggered
  self.fireworkBase:setSizeVariation(0.5)
  self.fireworkBase:setSizes(0.8, 0.6, 0.4, 0.2)
  self.fireworkBase:setSpeed(100, 300)
  self.fireworkBase:setDirection(-math.pi/2)  -- Up
  self.fireworkBase:setSpread(math.pi/8)
  self.fireworkBase:setLinearAcceleration(0, 200, 0, 300)  -- Gravity
  self.fireworkBase:setColors(
      1, 1, 1, 1,      -- White
      1, 0.8, 0, 1,    -- Yellow/orange
      1, 0.4, 0, 0.8   -- Orange/red fade
  )

  -- Explosion particle template (will be cloned when needed)
  self.fireworkExplosion = love.graphics.newParticleSystem(love.graphics.newCanvas(3, 3), 300)

  -- Draw a simple particle on the canvas
  love.graphics.setCanvas(self.fireworkExplosion:getTexture())
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 3, 3)
  love.graphics.setCanvas()

  -- Configure the explosion
  self.fireworkExplosion:setParticleLifetime(0.3, 1.5)
  self.fireworkExplosion:setEmissionRate(0)
  self.fireworkExplosion:setSizeVariation(0.5)
  self.fireworkExplosion:setSizes(0.8, 0.6, 0.4, 0.1)
  self.fireworkExplosion:setSpeed(50, 200)
  self.fireworkExplosion:setDirection(0)
  self.fireworkExplosion:setSpread(math.pi * 2)  -- 360 degrees
  self.fireworkExplosion:setLinearAcceleration(0, 100, 0, 200)  -- Gravity
  self.fireworkExplosion:setLinearDamping(0.5)

  -- Sparkle effect
  self.fireworkExplosion:setSpin(-2, 2)
  self.fireworkExplosion:setSpinVariation(1.0)
end

-- Function to set the player reference
function ParticleSystem:setPlayer(player)
  self.player = player
end

-- Function to set the world reference
function ParticleSystem:setWorld(world)
  self.world = world
end

function  ParticleSystem:updateDustParticles(dt)
  -- Update the particle system
  self.dustParticles:update(dt)

  -- Only emit dust when running on the ground
  local isRunning = self.player.vx ~= 0 and self.player.onGround
  local playerMovementState = self.player.animation.state

  if isRunning and playerMovementState == "run" then
      -- Position particles at the player's feet, slightly behind based on direction
      local particleX = self.player.x
      local particleY = self.player.y + self.player.height/2 - 2  -- At the player's feet, slightly higher

      -- Proper direction angles for upward movement
      -- In LÖVE, -π/2 is straight up, so we adjust slightly from that base
      if self.player.facing == "right" then
          particleX = particleX - 8  -- Slightly behind when facing right
          -- When facing right, we want particles to go up and slightly back (left)
          -- Less steep angle for more gentle rise
          self.dustParticles:setDirection(-math.pi/2 - math.pi/12)  -- Up and slightly left
      else
          particleX = particleX + 8  -- Slightly behind when facing left
          -- When facing left, we want particles to go up and slightly back (right)
          -- Less steep angle for more gentle rise
          self.dustParticles:setDirection(-math.pi/2 + math.pi/12)  -- Up and slightly right
      end

      -- Position the emitter
      self.dustParticles:setPosition(particleX, particleY)

      -- Control emission rate based on horizontal speed but at lower rate
      local speedFactor = math.abs(self.player.vx) / self.player.speed
      self.dustParticles:setEmissionRate(12 * speedFactor)  -- Slightly increased for more consistent dust

      -- Emit a larger burst when direction changes or player starts moving
      if (self.lastPlayerX == 0 or (self.player.vx > 0 and self.lastPlayerX < 0) or
          (self.player.vx < 0 and self.lastPlayerX > 0)) then
          -- For direction changes, emit particles with near-vertical trajectory
          local originalDirection = self.dustParticles:getDirection()
          local originalSpeed = {self.dustParticles:getSpeed()}

          -- Straight up is -π/2, with gentler velocity
          self.dustParticles:setDirection(-math.pi/2)
          self.dustParticles:setSpread(math.pi/10)
          self.dustParticles:setSpeed(10, 25)  -- Reduced burst speed
          self.dustParticles:emit(5)          -- Emit particles

          -- Restore original settings
          self.dustParticles:setDirection(originalDirection)
          self.dustParticles:setSpread(math.pi/7)
          self.dustParticles:setSpeed(unpack(originalSpeed))
      end

      -- Add less frequent but larger bursts for more dynamic effect
      self.dustEmitTimer = self.dustEmitTimer + dt
      if self.dustEmitTimer > 0.4 then  -- Less frequent
          -- Small burst with slightly higher velocity for mid-run particles
          local originalSpeed = {self.dustParticles:getSpeed()}
          self.dustParticles:setSpeed(originalSpeed[1] * 1.2, originalSpeed[2] * 1.2)
          self.dustParticles:emit(2)  -- Fewer particles per burst
          self.dustParticles:setSpeed(unpack(originalSpeed))
          self.dustEmitTimer = 0
      end

      -- Occasional larger puffs of dust with high vertical trajectory
      self.burstEmitTimer = self.burstEmitTimer + dt
      if self.burstEmitTimer > 1.2 then  -- Every 1.2 seconds
          -- Set temporary larger size for next few particles and vertical trajectory
          local originalSizes = {self.dustParticles:getSizes()}
          local originalDirection = self.dustParticles:getDirection()
          local originalSpread = self.dustParticles:getSpread()
          local originalSpeed = {self.dustParticles:getSpeed()}

          -- Configure for a big vertical burst - but more gentle
          self.dustParticles:setSizes(2.2, 1.8, 1.4, 0.9, 0.4)  -- Slightly smaller
          self.dustParticles:setDirection(-math.pi/2)           -- Straight up
          self.dustParticles:setSpread(math.pi/10)              -- Slightly wider spread
          self.dustParticles:setSpeed(15, 30)                  -- REDUCED upward speed

          -- Emit the big vertical burst
          self.dustParticles:emit(4)  -- Emit a few big particles

          -- Restore original settings
          self.dustParticles:setSizes(unpack(originalSizes))
          self.dustParticles:setDirection(originalDirection)
          self.dustParticles:setSpread(originalSpread)
          self.dustParticles:setSpeed(unpack(originalSpeed))

          self.burstEmitTimer = 0
      end
  else
      -- Stop emitting when not running
      self.dustParticles:setEmissionRate(0)
  end

  -- Remember player's velocity for next frame
  self.lastPlayerX = self.player.vx
  self.lastPlayerY = self.player.vy
end

function ParticleSystem:updateBlockParticles(dt)
  local i = 1
  while i <= #self.activeBlockParticles do
      local particleSystem = self.activeBlockParticles[i]
      particleSystem.system:update(dt)
      particleSystem.timeRemaining = particleSystem.timeRemaining - dt

      -- Remove expired particle systems
      if particleSystem.timeRemaining <= 0 and particleSystem.system:getCount() == 0 then
          table.remove(self.activeBlockParticles, i)
      else
          i = i + 1
      end
  end
end

function ParticleSystem:updatePlaceParticles(dt)
  local i = 1
  while i <= #self.activePlaceParticles do
      local particleSystem = self.activePlaceParticles[i]
      particleSystem.system:update(dt)
      particleSystem.timeRemaining = particleSystem.timeRemaining - dt

      -- Remove expired particle systems
      if particleSystem.timeRemaining <= 0 and particleSystem.system:getCount() == 0 then
          table.remove(self.activePlaceParticles, i)
      else
          i = i + 1
      end
  end
end

function ParticleSystem:updateLandingParticles(dt)
  local i = 1
  while i <= #self.playerTracking.landingParticles do
      local particleSystem = self.playerTracking.landingParticles[i]
      particleSystem.system:update(dt)
      particleSystem.timeRemaining = particleSystem.timeRemaining - dt

      -- Remove expired particle systems
      if particleSystem.timeRemaining <= 0 and particleSystem.system:getCount() == 0 then
          table.remove(self.playerTracking.landingParticles, i)
      else
          i = i + 1
      end
  end
end

function ParticleSystem:updateFireworkParticles(dt)
  if not self.fireworkParticles then
    print("WARNING: self.fireworkParticles is nil in updateFireworkParticles")
    self.fireworkParticles = {}
    return
  end

  local i = 1
  while i <= #self.fireworkParticles do
      local firework = self.fireworkParticles[i]
      firework.system:update(dt)
      firework.timeRemaining = firework.timeRemaining - dt

      -- For launch type, check if we should create an explosion
      if firework.type == "launch" and not firework.explosionCreated then
          -- Get the current particle count
          local count = firework.system:getCount()

          -- If particles are mostly gone or timer is low, trigger explosion
          if (count < 2 or firework.timeRemaining < 0.8) and firework.timeRemaining > 0.1 then
              -- Modified to explode at a lower height (reduced from 100-200 range to 50-100)
              self:createExplosion(firework.x, firework.y - 50 - math.random(50), firework.explosionColors)
              firework.explosionCreated = true
          end
      end

      -- Remove expired particle systems
      if firework.timeRemaining <= 0 and firework.system:getCount() == 0 then
          table.remove(self.fireworkParticles, i)
      else
          i = i + 1
      end
  end

  -- Update the LISA sequence display timer
  if self.lisaSequence.displayTimer > 0 then
      self.lisaSequence.displayTimer = self.lisaSequence.displayTimer - dt
      if self.lisaSequence.displayTimer <= 0 then
          -- Only reset the sequence when the timer expires
          -- This means the completed sequence (including the "A") will stay visible
          -- for the full duration of displayTimer
          self.lisaSequence.currentIndex = 0
      end
  end
end

function ParticleSystem:UpdateAllParticles(dt)
  self:updateDustParticles(dt)
  self:updateBlockParticles(dt)
  self:updatePlaceParticles(dt)
  self:updateLandingParticles(dt)
  self:updateFireworkParticles(dt)
end

-- Function to launch a firework from a position
function ParticleSystem:launchFirework(x, y)
  -- Clone the base firework system
  local newFirework = self.fireworkBase:clone()

  -- Position at specified position
  newFirework:setPosition(x, y)

  -- Emit a few particles for the launch trail
  newFirework:emit(10)

  -- Create and track the firework
  table.insert(self.fireworkParticles, {
      system = newFirework,
      type = "launch",
      x = x,
      y = y,
      timeRemaining = 1.5,
      explosionCreated = false,
      explosionColors = self:getRandomExplosionColors()
  })

  -- Play a sound effect if available
  -- if self.fireworkSound then
  --     self.fireworkSound:play()
  -- end
end

-- Get random colors for the firework explosion
function ParticleSystem:getRandomExplosionColors()
  -- Choose a random color scheme
  local colorSchemes = {
      -- Red/pink
      {
          {1, 0.2, 0.2, 1},    -- Start
          {1, 0.4, 0.4, 0.7},  -- Mid
          {1, 0.6, 0.6, 0.3}   -- End
      },
      -- Blue/cyan
      {
          {0.2, 0.4, 1, 1},
          {0.4, 0.6, 1, 0.7},
          {0.6, 0.8, 1, 0.3}
      },
      -- Green/yellow
      {
          {0.2, 1, 0.3, 1},
          {0.5, 1, 0.5, 0.7},
          {0.7, 1, 0.3, 0.3}
      },
      -- Purple/pink
      {
          {0.8, 0.2, 1, 1},
          {0.9, 0.4, 1, 0.7},
          {1, 0.6, 1, 0.3}
      },
      -- Gold/yellow
      {
          {1, 0.8, 0.1, 1},
          {1, 0.9, 0.3, 0.7},
          {1, 1, 0.5, 0.3}
      }
  }

  return colorSchemes[math.random(#colorSchemes)]
end

-- Create an explosion effect at the specified position
function ParticleSystem:createExplosion(x, y, colors)
  -- Clone the explosion system
  local explosion = self.fireworkExplosion:clone()

  -- Position the explosion
  explosion:setPosition(x, y)

  -- Set colors
  if colors then
      explosion:setColors(
          colors[1][1], colors[1][2], colors[1][3], colors[1][4],
          colors[2][1], colors[2][2], colors[2][3], colors[2][4],
          colors[3][1], colors[3][2], colors[3][3], colors[3][4]
      )
  end

  -- Emit particles in all directions
  explosion:emit(100 + math.random(100))

  -- Add to the active particles
  table.insert(self.fireworkParticles, {
      system = explosion,
      type = "explosion",
      x = x,
      y = y,
      timeRemaining = 1.5
  })
end

-- Function to emit particles when player lands
function ParticleSystem:emitLandingParticles(x, y, count, intensity)
  -- Clone the particle system for this landing
  local newParticleSystem = self.landingParticles:clone()
  newParticleSystem:setPosition(x, y)

  -- Scale speeds based on landing intensity
  local baseSpeed = {newParticleSystem:getSpeed()}
  local scaledMinSpeed = baseSpeed[1] * (0.7 + intensity * 0.6)
  local scaledMaxSpeed = baseSpeed[2] * (0.7 + intensity * 0.6)
  newParticleSystem:setSpeed(scaledMinSpeed, scaledMaxSpeed)

  -- Add a ground impact "burst" effect going left and right
  -- Left side burst
  newParticleSystem:setDirection(math.pi)  -- Left
  newParticleSystem:emit(math.floor(count / 2))

  -- Right side burst
  newParticleSystem:setDirection(0)  -- Right
  newParticleSystem:emit(math.floor(count / 2))

  -- Add some vertical particles too for a more dynamic effect
  local lowIntensityCount = math.floor(count / 4)
  if intensity > 0.5 and lowIntensityCount > 0 then
      newParticleSystem:setDirection(-math.pi/2)  -- Upward
      newParticleSystem:setSpread(math.pi/4)  -- Narrower spread
      newParticleSystem:emit(lowIntensityCount)
  end

  -- Reset spread for future emissions
  newParticleSystem:setSpread(math.pi * 0.7)

  -- Add to active particle systems
  table.insert(self.playerTracking.landingParticles, {
      system = newParticleSystem,
      timeRemaining = 1.0  -- 1 second lifetime for landing particles
  })
end

-- Function to emit particles when a block is broken
function ParticleSystem:emitBlockBreakParticles(worldX, worldY, blockType)
    -- Check if world reference is set
    if not self.world then
        print("WARNING: self.world is nil in emitBlockBreakParticles")
        return
    end

    -- Convert to pixel coordinates for the center of the block
    local pixelX = math.floor(worldX / self.world.tileSize) * self.world.tileSize + self.world.tileSize / 2
    local pixelY = math.floor(worldY / self.world.tileSize) * self.world.tileSize + self.world.tileSize / 2

    -- Clone the particle system for this specific block break
    local newParticleSystem = self.blockBreakParticles:clone()
    newParticleSystem:setPosition(pixelX, pixelY)

    -- Set color based on block type
    local blockInfo = self.world.blocks[blockType]
    if blockInfo then
        local r, g, b = unpack(blockInfo.color or {0.8, 0.8, 0.8})
        -- Set gradient of colors from full color to faded
        newParticleSystem:setColors(
            r, g, b, 1.0,    -- Initial color
            r, g, b, 0.8,    -- Mid-life
            r, g, b, 0.5,    -- Later
            r, g, b, 0.2,    -- Near end
            r, g, b, 0.0     -- End color (fade out)
        )
    else
        -- Default colors for unknown block types
        newParticleSystem:setColors(
            0.8, 0.8, 0.8, 1.0,
            0.8, 0.8, 0.8, 0.8,
            0.8, 0.8, 0.8, 0.5,
            0.8, 0.8, 0.8, 0.2,
            0.8, 0.8, 0.8, 0.0
        )
    end

    -- Emit a burst of particles
    newParticleSystem:emit(20 + math.random(10))

    -- Add to active particle systems with lifetime
    table.insert(self.activeBlockParticles, {
        system = newParticleSystem,
        timeRemaining = 1.0  -- 1 second lifetime
    })
end

-- Function to emit particles when a block is placed
function ParticleSystem:emitBlockPlaceParticles(worldX, worldY, blockType)
    -- Check if world reference is set
    if not self.world then
        print("WARNING: self.world is nil in emitBlockPlaceParticles")
        return
    end

    -- Convert to pixel coordinates for the center of the block
    local gridX = math.floor(worldX / self.world.tileSize) + 1
    local gridY = math.floor(worldY / self.world.tileSize) + 1
    local pixelX = (gridX - 1) * self.world.tileSize + self.world.tileSize / 2
    local pixelY = (gridY - 1) * self.world.tileSize + self.world.tileSize / 2

    -- Clone the particle system for this specific block placement
    local newParticleSystem = self.blockPlaceParticles:clone()

    -- Set color based on block type
    local blockInfo = self.world.blocks[blockType]
    if blockInfo then
        local r, g, b = unpack(blockInfo.color or {0.8, 0.8, 0.8})
        -- Set gradient of colors from faded to full color then faded
        newParticleSystem:setColors(
            r, g, b, 0.1,    -- Initial faded
            r, g, b, 0.8,    -- Near-peak opacity
            r*1.2, g*1.2, b*1.2, 0.9,  -- Peak brightness (slightly brighter)
            r, g, b, 0.6,    -- Post-peak
            r, g, b, 0.0     -- End color (fade out)
        )
    else
        -- Default colors for unknown block types
        newParticleSystem:setColors(
            1, 1, 1, 0.1,
            1, 1, 1, 0.7,
            1, 1, 1, 0.8,
            1, 1, 1, 0.4,
            1, 1, 1, 0.0
        )
    end

    -- Create particles around the edges of the block, not just center
    local halfSize = self.world.tileSize / 2
    for i = 1, 4 do -- Emit from 4 positions - N, E, S, W points
        local offsetX, offsetY

        if i == 1 then -- Top
            offsetX = 0
            offsetY = -halfSize + 2
        elseif i == 2 then -- Right
            offsetX = halfSize - 2
            offsetY = 0
        elseif i == 3 then -- Bottom
            offsetX = 0
            offsetY = halfSize - 2
        else -- Left
            offsetX = -halfSize + 2
            offsetY = 0
        end

        newParticleSystem:setPosition(pixelX + offsetX, pixelY + offsetY)

        -- Change direction based on side
        if i == 1 then -- Top edge
            newParticleSystem:setDirection(-math.pi/2) -- Up
            newParticleSystem:setSpread(math.pi/4)
        elseif i == 2 then -- Right edge
            newParticleSystem:setDirection(0) -- Right
            newParticleSystem:setSpread(math.pi/4)
        elseif i == 3 then -- Bottom edge
            newParticleSystem:setDirection(math.pi/2) -- Down
            newParticleSystem:setSpread(math.pi/4)
        else -- Left edge
            newParticleSystem:setDirection(math.pi) -- Left
            newParticleSystem:setSpread(math.pi/4)
        end

        -- Emit particles from this position
        newParticleSystem:emit(3 + math.random(2))
    end

    -- Also emit a small burst from the center for a "poof" effect
    newParticleSystem:setPosition(pixelX, pixelY)
    newParticleSystem:setDirection(0)
    newParticleSystem:setSpread(math.pi * 2) -- Full 360 degrees
    newParticleSystem:emit(6 + math.random(3))

    -- Add to active particle systems with lifetime
    table.insert(self.activePlaceParticles, {
        system = newParticleSystem,
        timeRemaining = 0.8  -- 0.8 second lifetime (shorter than break effect)
    })
end

return ParticleSystem
