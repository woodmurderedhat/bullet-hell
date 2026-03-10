# Polychrome Void - Documentation Index

Welcome to the Polychrome Void documentation. This index provides an overview of all available documentation.

## Getting Started

| Document | Description |
|----------|-------------|
| [README](../README.md) | Project overview, quick start, and directory structure |

## Development Guide

| Document | Description |
|----------|-------------|
| [ARCHITECTURE](ARCHITECTURE.md) | Game architecture, systems, and design patterns |
| [SPRITE_GENERATOR](SPRITE_GENERATOR.md) | Python sprite generation tool documentation |
| [MIGRATION_SCRIPT](MIGRATION_SCRIPT.md) | Sprite data migration automation |

## Testing & Validation

| Document | Description |
|----------|-------------|
| [VALIDATION_TESTS](VALIDATION_TESTS.md) | Automated test infrastructure |

## Migration Planning

| Document | Description |
|----------|-------------|
| [14_SPRITE_MIGRATION_PLAN_32x32](14_SPRITE_MIGRATION_PLAN_32x32.md) | Detailed sprite migration roadmap |

## Quick Reference

### Sprite System

1. **Generate sprites**: Run [`spaceship-sprite-generator/main.py`](../spaceship-sprite-generator/main.py)
2. **Migrate data**: Run [`migrate_sprites.py`](../migrate_sprites.py)
3. **Verify**: Run validation tests

### Performance Targets

- 60 FPS on Raspberry Pi 5
- 1280x720 resolution
- 150 enemies / 4000 bullets / 300 effects

### Project Structure

```
bullet-hell/
├── README.md                 # Main project readme
├── migrate_sprites.py        # Migration script
├── docs/                     # This documentation
│   ├── ARCHITECTURE.md
│   ├── SPRITE_GENERATOR.md
│   ├── MIGRATION_SCRIPT.md
│   ├── VALIDATION_TESTS.md
│   └── 14_SPRITE_MIGRATION_PLAN_32x32.md
├── spaceship-sprite-generator/
│   ├── main.py
│   ├── sprite_generator.py
│   └── requirements.txt
└── polychrome-void/
    └── polychrome-void/
        ├── assets/
        ├── combat/
        ├── core/
        ├── data/
        ├── player/
        ├── scenes/
        ├── systems/
        ├── tools/
        └── ui/
```

## Contributing

When contributing to the project:

1. Follow the [Architecture](ARCHITECTURE.md) guidelines
2. Maintain performance constraints
3. Update documentation for new features
4. Test on all target platforms

## Need Help?

- Check the relevant documentation above
- Review code comments for API details
- Examine existing implementations for patterns
