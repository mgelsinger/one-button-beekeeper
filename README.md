# One Button Beekeeper

A cozy idle clicker game where you tend to your very own bee colony. Watch your bees buzz about, collect sweet honey, and grow your apiary into a thriving honey empire — all with a single button.

Built with **Godot 4.5** | GDScript

---

## Gameplay

Your bees work tirelessly, filling the hive with delicious honey. Your job? Collect it at the perfect moment and reinvest in your buzzing enterprise.

**The Loop:**
1. **Watch** — Bees automatically produce honey and fill your hive
2. **Collect** — Tap the button when you're ready to harvest
3. **Upgrade** — Spend honey to expand your operation
4. **Repeat** — Watch your colony flourish

## Features

- **Relaxing one-button gameplay** — No stress, just bees
- **Three upgrade paths:**
  - **More Bees** — Increase your honey production rate
  - **Bigger Hive** — Expand your storage capacity
  - **Better Flowers** — Boost production even further
- **Charming visual feedback** — Watch your hive grow, bees multiply, and flowers bloom
- **Auto-save** — Your progress is saved every 15 seconds
- **Audio controls** — Adjust volume or play in peaceful silence
- **Clean, cozy aesthetic** — Designed for maximum comfort

## Screenshots

*Coming soon!*

## Getting Started

### Play the Game

**Windows:** Download the latest release from the [Releases](../../releases) page.

### Run from Source

1. Install [Godot 4.5](https://godotengine.org/download)
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/one-button-beekeeper.git
   ```
3. Open the project in Godot
4. Press F5 to play

### Build from Source

Run the PowerShell build script:
```powershell
./export_build.ps1
```

Builds are output to the `builds/` directory.

## Game Design

### Upgrade Economy

| Upgrade | Base Cost | Effect per Level | Cost Growth |
|---------|-----------|------------------|-------------|
| More Bees | 10 | +0.2 honey/sec | 1.25x |
| Bigger Hive | 15 | +10 capacity | 1.28x |
| Better Flowers | 30 | +0.5 honey/sec | 1.30x |

The exponential cost scaling creates satisfying progression milestones while encouraging strategic decisions between production and storage upgrades.

## Technical Details

### Project Structure

```
one-button-beekeeper/
├── scripts/           # Game logic (GDScript)
│   ├── Main.gd        # Core game mechanics
│   ├── GameTest.gd    # Automated test suite
│   ├── AudioManager.gd
│   └── ...
├── scenes/            # Godot scenes (.tscn)
├── assets/
│   ├── audio/         # Sound effects
│   └── sprites/       # Game graphics
└── builds/            # Export output
```

### Save System

Game state is persisted to `user://save.json`:
- Total honey collected
- Current hive storage
- All upgrade levels

### Testing

The project includes a comprehensive automated test suite:

```bash
# Run tests in headless mode
godot --headless --script scripts/GameTest.gd
```

Tests cover:
- Initial state validation
- Production mechanics
- Upgrade cost formulas
- Save/load persistence
- Visual state consistency

## Contributing

Contributions are welcome! Whether it's:
- Bug fixes
- New upgrade ideas
- Art improvements
- Sound design
- Balance tweaks

Feel free to open an issue or submit a pull request.

## Roadmap

Potential future features:
- [ ] Achievements system
- [ ] Seasonal events
- [ ] New upgrade types
- [ ] Prestige/rebirth mechanics
- [ ] More visual flair and animations
- [ ] Mobile support

## License

*License TBD*

---

<p align="center">
  <i>Made with honey and Godot</i>
</p>
