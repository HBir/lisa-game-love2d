
local DebugMenu = {}

-- Function to draw the sprite debug view
function DebugMenu:DrawDebugMenu(page, game)
  page = page or 1  -- Default to page 1 if no page is specified

  -- Common setup for all debug pages
  -- Draw semi-transparent background
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", 0, 0, game.width, game.height)

  -- Page-specific content
  if page == 1 or page == 2 then
      -- SPRITE DEBUG VIEW (page 1 shows top portion, page 2 shows more blocks)
      -- Draw title with page information
      love.graphics.setColor(1, 1, 1, 1)
      if page == 1 then
          love.graphics.print("SPRITE DEBUG VIEW - PAGE 1 (Press X to see more sprites)", 10, 10)
      else
          love.graphics.print("SPRITE DEBUG VIEW - PAGE 2 (Press X to close)", 10, 10)
      end

      -- Get the sprite sheet and tilesize from the block registry
      local spriteSheet = game.world.blockRegistry.spriteSheet
      local tileSize = game.world.blockRegistry.tilesetSize

      -- Calculate how many sprites fit per row based on window width
      local columns = 11 --math.floor(game.width / (tileSize * 4))
      local spacing = 0 -- Space between sprites horizontally
      local verticalSpacing = 35 -- Increased vertical spacing to make room for text
      local scale = 3 -- Scale up sprites for better visibility

      -- Calculate rows per page
      local rowsPerPage = math.floor((game.height - 60) / (tileSize * scale + verticalSpacing))

      local quads = game.world.blockRegistry.blockQuads

      -- sort quads
      local sortedQuads = {}
      for key, quad in pairs(quads) do
          table.insert(sortedQuads, {key = key, quad = quad})
      end

      table.sort(sortedQuads, function(a, b)
          return tostring(a.key) < tostring(b.key)
      end)

      -- Calculate starting row based on current page
      local pageOffset = (page - 1) * rowsPerPage

      -- Draw each sprite
      local row = 0
      local col = 0
      local startY = 50 -- Start below the title, increased for better spacing
      local displayedRows = 0
      local totalRows = math.ceil(#sortedQuads / columns)

      local shownCount = 0

      for i, quad in pairs(sortedQuads) do
          -- Calculate which row and column this sprite belongs to
          local spriteRow = math.floor((i-1) / columns)
          local spriteCol = (i-1) % columns

          -- Only display sprites for the current page
          if spriteRow >= pageOffset and spriteRow < pageOffset + rowsPerPage then
              local adjustedRow = spriteRow - pageOffset
              local x = 10 + spriteCol * (tileSize * scale + spacing)
              local y = startY + adjustedRow * (tileSize * scale + verticalSpacing)

              -- Draw sprite
              love.graphics.setColor(1, 1, 1, 1)
              love.graphics.draw(spriteSheet, quad.quad, x, y, 0, scale, scale)

              local blockTypeStr = tostring(quad.key)
              local textWidth = blockTypeStr:len() * 6 -- Approximate width
              love.graphics.setColor(0, 0, 0, 0.7)
              love.graphics.rectangle("fill", x, y + tileSize * scale + 2, textWidth, 14)
              -- Draw the text
              love.graphics.setColor(1, 1, 0.5, 1)
              love.graphics.print(blockTypeStr, x, y + tileSize * scale + 2, 0, 0.8, 0.8)

              shownCount = shownCount + 1
          end
      end

      -- Show page information at the bottom
      love.graphics.setColor(1, 1, 1, 0.8)
      love.graphics.print("Showing " .. shownCount .. " of " .. #sortedQuads .. " sprites (Page " .. page .. " of " .. math.ceil(totalRows / rowsPerPage) .. ")",
                         10, game.height - 30)

  elseif page == 3 then
      -- GAME STATS PAGE (now page 3)
      -- Draw title
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("GAME STATS DEBUG (Press X to close)", 10, 10)

      -- Draw game stats
      local startY = 50
      local lineHeight = 24
      local statsX = 20

      -- Player information
      love.graphics.setColor(0.8, 1, 0.8, 1) -- Light green for player stats
      love.graphics.print("PLAYER STATS:", statsX, startY)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("Position: X=" .. math.floor(game.player.x) .. ", Y=" .. math.floor(game.player.y),
                         statsX + 20, startY + lineHeight)
      love.graphics.print("Velocity: X=" .. string.format("%.2f", game.player.vx) ..
                         ", Y=" .. string.format("%.2f", game.player.vy),
                         statsX + 20, startY + lineHeight * 2)
      love.graphics.print("Animation: " .. game.player.animation.state .. " (Frame " ..
                         game.player.animation.frame .. ")",
                         statsX + 20, startY + lineHeight * 3)
      love.graphics.print("On Ground: " .. tostring(game.player.onGround),
                         statsX + 20, startY + lineHeight * 4)

      -- World information
      love.graphics.setColor(0.8, 0.8, 1, 1) -- Light blue for world stats
      love.graphics.print("WORLD STATS:", statsX, startY + lineHeight * 6)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("World Size: " .. game.world.width .. " x " .. game.world.height .. " tiles",
                         statsX + 20, startY + lineHeight * 7)
      love.graphics.print("Tile Size: " .. game.world.tileSize .. " pixels",
                         statsX + 20, startY + lineHeight * 8)

      -- Camera information
      love.graphics.setColor(1, 0.8, 0.8, 1) -- Light red for camera stats
      love.graphics.print("CAMERA STATS:", statsX, startY + lineHeight * 10)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("Position: X=" .. math.floor(game.camera.x) .. ", Y=" .. math.floor(game.camera.y),
                         statsX + 20, startY + lineHeight * 11)
      love.graphics.print("Scale: " .. game.camera.scale,
                         statsX + 20, startY + lineHeight * 12)

      -- NPC count
      love.graphics.setColor(1, 1, 0.8, 1) -- Light yellow for NPC stats
      love.graphics.print("NPC STATS:", statsX, startY + lineHeight * 14)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("Active NPCs: " .. #game.npcs,
                         statsX + 20, startY + lineHeight * 15)

      -- Performance metrics (if available)
      love.graphics.setColor(1, 0.8, 1, 1) -- Light purple for performance stats
      love.graphics.print("PERFORMANCE:", statsX, startY + lineHeight * 17)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print("FPS: " .. love.timer.getFPS(),
                         statsX + 20, startY + lineHeight * 18)
      love.graphics.print("Memory Used: " .. string.format("%.2f", collectgarbage("count") / 1024) .. " MB",
                         statsX + 20, startY + lineHeight * 19)
  end
end

return DebugMenu
