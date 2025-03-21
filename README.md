# Lisa's Game

A Terraria-like 2D sandbox game built with LÖVE2D (pronounced "love"), where you play as a princess who can place and remove blocks to build structures in a procedurally generated world.

## Features

- Scrolling world both horizontally and vertically
- Character physics with gravity and collision detection
- Terrain generation with different block types
- Place and remove blocks to build structures
- Princess character with simple animations

## Controls

- **A / Left Arrow**: Move left
- **D / Right Arrow**: Move right
- **W / Up Arrow / Space**: Jump
- **Left Mouse Button**: Remove block
- **Right Mouse Button**: Place selected block
- **Mouse Wheel**: Cycle through block types
- **Escape**: Pause game

## Running the Game

1. Install [LÖVE2D](https://love2d.org/) (version 11.x recommended)
2. Clone this repository or download the source code
3. Run the game using one of these methods:
   - Drag the game folder onto the LÖVE application
   - From the command line: `love /path/to/game/folder`
   - On macOS: `/Applications/love.app/Contents/MacOS/love /path/to/game/folder`
   - On Windows: `"C:\Program Files\LOVE\love.exe" "C:\path\to\game\folder"`

## Development

This game is structured with the following modules:

- `main.lua`: Entry point and LÖVE callbacks
- `game.lua`: Main game class that manages game state
- `world.lua`: Manages the block grid and terrain generation
- `player.lua`: Handles the princess character and controls
- `camera.lua`: Manages view scrolling and transformations
- `block.lua`: Defines block properties

## Next Steps

Future enhancements could include:
- Better sprites and animations
- More block types and items
- Inventory system
- Enemies and combat
- Background parallax layers
- Day/night cycle
- Sound effects and music

## License

MIT License 