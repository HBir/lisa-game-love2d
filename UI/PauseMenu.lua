local PauseMenu = {}
PauseMenu.__index = PauseMenu

-- Drawing the pause menu
function PauseMenu:new(game)
  local self = setmetatable({}, PauseMenu)
  self.game = game
  return self
end

-- Drawing the pause menu
function PauseMenu:drawPauseMenu()
  -- Semi-transparent background
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, self.game.width, self.game.height)

  -- Menu container
  local menuWidth = 300
  local menuHeight = 310  -- Increased to accommodate the exit button
  local menuX = (self.game.width - menuWidth) / 2
  local menuY = (self.game.height - menuHeight) / 2

  -- Draw menu background
  love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
  love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, 10, 10)
  love.graphics.setColor(0.4, 0.4, 0.6, 1)
  love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight, 10, 10)

  -- Draw menu title
  love.graphics.setColor(1, 1, 1, 1)
  local titleText = "Game Paused"
  local font = love.graphics.getFont()
  local titleWidth = font:getWidth(titleText) * 1.5 -- Scale for larger text
  local titleX = menuX + (menuWidth - titleWidth) / 2
  love.graphics.print(titleText, titleX, menuY + 20, 0, 1.5, 1.5)

  -- Draw menu options
  love.graphics.setColor(1, 1, 1, 0.9)

  -- Button dimensions
  local buttonWidth = 200
  local buttonHeight = 40
  local buttonX = menuX + (menuWidth - buttonWidth) / 2
  local buttonSpacing = 20
  local buttonY = menuY + 80

  -- Resume button
  local resumeButtonY = buttonY
  love.graphics.setColor(0.3, 0.5, 0.3, 1)
  love.graphics.rectangle("fill", buttonX, resumeButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(0.2, 0.3, 0.2, 1)
  love.graphics.rectangle("line", buttonX, resumeButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(1, 1, 1, 1)
  local resumeText = "Resume Game"
  local resumeTextWidth = font:getWidth(resumeText)
  love.graphics.print(resumeText, buttonX + (buttonWidth - resumeTextWidth) / 2, resumeButtonY + 10)

  -- Save button
  local saveButtonY = buttonY + buttonHeight + buttonSpacing
  love.graphics.setColor(0.3, 0.3, 0.5, 1)
  love.graphics.rectangle("fill", buttonX, saveButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(0.2, 0.2, 0.3, 1)
  love.graphics.rectangle("line", buttonX, saveButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(1, 1, 1, 1)
  local saveText = "Save Game"
  local saveTextWidth = font:getWidth(saveText)
  love.graphics.print(saveText, buttonX + (buttonWidth - saveTextWidth) / 2, saveButtonY + 10)

  -- Load button
  local loadButtonY = saveButtonY + buttonHeight + buttonSpacing
  love.graphics.setColor(0.3, 0.3, 0.5, 1)
  love.graphics.rectangle("fill", buttonX, loadButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(0.2, 0.2, 0.3, 1)
  love.graphics.rectangle("line", buttonX, loadButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(1, 1, 1, 1)
  local loadText = "Load Game"
  local loadTextWidth = font:getWidth(loadText)
  love.graphics.print(loadText, buttonX + (buttonWidth - loadTextWidth) / 2, loadButtonY + 10)

  -- Exit button
  local exitButtonY = loadButtonY + buttonHeight + buttonSpacing
  love.graphics.setColor(0.5, 0.3, 0.3, 1) -- Red-ish color for exit button
  love.graphics.rectangle("fill", buttonX, exitButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(0.3, 0.2, 0.2, 1) -- Darker border
  love.graphics.rectangle("line", buttonX, exitButtonY, buttonWidth, buttonHeight, 5, 5)
  love.graphics.setColor(1, 1, 1, 1)
  local exitText = "Exit Game"
  local exitTextWidth = font:getWidth(exitText)
  love.graphics.print(exitText, buttonX + (buttonWidth - exitTextWidth) / 2, exitButtonY + 10)

  -- Store button positions and dimensions for interaction
  self.buttons = {
      resume = {x = buttonX, y = resumeButtonY, width = buttonWidth, height = buttonHeight},
      save = {x = buttonX, y = saveButtonY, width = buttonWidth, height = buttonHeight},
      load = {x = buttonX, y = loadButtonY, width = buttonWidth, height = buttonHeight},
      exit = {x = buttonX, y = exitButtonY, width = buttonWidth, height = buttonHeight}
  }

  -- Draw esc to resume hint
  love.graphics.setColor(0.8, 0.8, 0.8, 0.7)
  local hintText = "Press ESC again to resume"
  local hintWidth = font:getWidth(hintText)
  love.graphics.print(hintText, menuX + (menuWidth - hintWidth) / 2, menuY + menuHeight - 30)

  -- Reset color
  love.graphics.setColor(1, 1, 1, 1)
end

-- Check if point is inside rectangle
function PauseMenu:pointInRect(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.width and
         y >= rect.y and y <= rect.y + rect.height
end

-- Function to handle pause menu clicks
function PauseMenu:handlePauseMenuClick(x, y)
  if not self.buttons then return false end

  if self:pointInRect(x, y, self.buttons.resume) then
      self.game.paused = false
      return true
  elseif self:pointInRect(x, y, self.buttons.save) then
      self.game:saveWorld()
      return true
  elseif self:pointInRect(x, y, self.buttons.load) then
      self.game:loadWorld()
      return true
  elseif self:pointInRect(x, y, self.buttons.exit) then
      love.event.quit()
      return true
  end

  return false
end

return PauseMenu