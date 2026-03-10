# Sprite Generator Documentation

## Overview

The Sprite Generator is a Python-based tool that procedurally generates 32x32 pixel spaceship sprites for the Polychrome Void bullet hell game. It uses the Python Imaging Library (Pillow) to create sprite sheets with multiple animation states.

**Location**: [`spaceship-sprite-generator/`](spaceship-sprite-generator/)

## Requirements

- Python 3.x
- Pillow>=10.0.0

### Installation

```bash
cd spaceship-sprite-generator
pip install -r requirements.txt
```

## Usage

### Basic Usage

```bash
cd spaceship-sprite-generator
python3 main.py
```

This generates all sprites to the current directory. To generate sprites to a specific location:

```python
from sprite_generator import generate_all_sprites

# Generate sprites to a custom directory
generate_all_sprites('/path/to/output')
```

## Output Structure

The generator creates the following directory structure:

```
sprites/
├── enemies/
│   ├── basic/
│   │   ├── basic_1_idle.png
│   │   ├── basic_1_move.png
│   │   ├── basic_1_hit.png
│   │   ├── basic_1_death.png
│   │   ├── basic_2_idle.png
│   │   ├── basic_2_move.png
│   │   ├── basic_2_hit.png
│   │   ├── basic_2_death.png
│   │   └── ... (5 variants × 4 states)
│   ├── medium/
│   │   └── ... (4 variants × 4 states)
│   └── heavy/
│       └── ... (3 variants × 4 states)
└── bosses/
    └── ... (2 variants × 4 states)
```

### Sprite Counts

| Category | Variants | States | Total |
|----------|----------|--------|-------|
| Basic Enemies | 5 | 4 | 20 |
| Medium Enemies | 4 | 4 | 16 |
| Heavy Enemies | 3 | 4 | 12 |
| Bosses | 2 | 4 | 8 |
| **Total** | | | **56** |

## Color Schemes

Each enemy tier has a distinct color palette:

### Basic Enemies (Blues/Cyans)

```python
'basic': {
    'primary': (64, 164, 223),      # Cyan-blue
    'secondary': (100, 200, 255),   # Light cyan
    'accent': (32, 100, 160),       # Darker blue
    'highlight': (150, 220, 255),  # Bright cyan
}
```

### Medium Enemies (Greens/Yellows)

```python
'medium': {
    'primary': (120, 200, 64),      # Green
    'secondary': (180, 230, 100),   # Light green
    'accent': (80, 150, 40),        # Dark green
    'highlight': (220, 255, 150),  # Bright yellow-green
}
```

### Heavy Enemies (Oranges/Reds)

```python
'heavy': {
    'primary': (220, 100, 50),      # Orange
    'secondary': (255, 150, 80),    # Light orange
    'accent': (180, 60, 30),        # Dark red-orange
    'highlight': (255, 200, 100),   # Bright orange
}
```

### Bosses (Purples/Magentas)

```python
'boss': {
    'primary': (160, 60, 180),      # Purple
    'secondary': (200, 100, 220),   # Light purple
    'accent': (100, 40, 120),       # Dark purple
    'highlight': (230, 150, 255),   # Bright magenta
}
```

## Sprite States

Each sprite has four animation states:

| State | Duration | Visual Effect |
|-------|----------|---------------|
| `idle` | N/A | Default standing sprite |
| `move` | N/A | Includes thruster flame effects |
| `hit` | 0.1s | White flash overlay (50% opacity) |
| `death` | 0.25s | Radial explosion particles |

## API Reference

### Core Functions

#### `generate_all_sprites(output_dir: str) -> None`

Generates all spaceship sprites and saves them to the specified directory.

**Parameters:**
- `output_dir` (str): Directory path where sprites will be saved

**Example:**
```python
generate_all_sprites('./output')
```

#### `generate_sprite(enemy_type: str, variant: int, state: str) -> Image`

Generates a single sprite based on type, variant, and state.

**Parameters:**
- `enemy_type` (str): One of 'basic', 'medium', 'heavy', 'boss'
- `variant` (int): Variant number (1-5 for basic, 1-4 for medium, 1-3 for heavy, 1-2 for boss)
- `state` (str): One of 'idle', 'move', 'hit', 'death'

**Returns:**
- PIL Image object

**Example:**
```python
from sprite_generator import generate_sprite
img = generate_sprite('boss', 1, 'idle')
img.save('boss_idle.png')
```

### Ship Generation Functions

- [`generate_basic_ship()`](spaceship-sprite-generator/sprite_generator.py:145) - Basic enemy ships (5 variants)
- [`generate_medium_ship()`](spaceship-sprite-generator/sprite_generator.py:197) - Medium enemy ships (4 variants)
- [`generate_heavy_ship()`](spaceship-sprite_generator/sprite_generator.py:263) - Heavy enemy ships (3 variants)
- [`generate_boss_ship()`](spaceship-sprite-generator/sprite_generator.py:333) - Boss ships (2 variants)

### Drawing Helper Functions

- [`draw_triangular_ship()`](spaceship-sprite-generator/sprite_generator.py:49) - Draw triangular shapes
- [`draw_diamond_ship()`](spaceship-sprite-generator/sprite_generator.py:78) - Draw diamond shapes
- [`draw_hexagon_ship()`](spaceship-sprite-generator/sprite_generator.py:89) - Draw hexagonal shapes
- [`draw_wing_ship()`](spaceship-sprite-generator/sprite_generator.py:100) - Draw winged shapes
- [`draw_circular_ship()`](spaceship-sprite-generator/sprite_generator.py:128) - Draw circular shapes
- [`add_details()`](spaceship-sprite-generator/sprite_generator.py:133) - Add detail elements

## Customization

### Adding New Color Schemes

To add a new color scheme, edit the `COLOR_SCHEMES` dictionary in [`sprite_generator.py`](spaceship-sprite-generator/sprite_generator.py:11):

```python
COLOR_SCHEMES = {
    'new_tier': {
        'primary': (R, G, B),        # Main ship color
        'secondary': (R, G, B),       # Secondary color
        'accent': (R, G, B),         # Accent/detail color
        'highlight': (R, G, B),      # Highlight color
    },
    # ... existing schemes
}
```

### Adding New Ship Designs

To add a new ship variant, create a new function or extend existing ones:

```python
def generate_new_ship(variant, colors, state='idle'):
    img = create_blank_image()
    draw = ImageDraw.Draw(img)
    
    # Your custom drawing code here
    
    # Apply state modifications
    if state == 'move':
        # Add thruster effects
    elif state == 'hit':
        # Add flash overlay
    elif state == 'death':
        # Add explosion particles
    
    return img
```

Then register it in the `generate_sprite()` function:

```python
def generate_sprite(enemy_type, variant, state='idle'):
    if enemy_type == 'new_tier':
        colors = COLOR_SCHEMES['new_tier']
        return generate_new_ship(variant, colors, state)
    # ... existing code
```

## Integration with Godot

After generating sprites, use the migration script ([`migrate_sprites.py`](migrate_sprites.py)) to update your Godot resource files with the new sprite paths:

```bash
python3 migrate_sprites.py
```

This will:
1. Scan all `.tres` files in `data/enemies/` and `data/bosses/`
2. Map entity IDs to the generated sprite sets
3. Add sprite path fields for each state

## Troubleshooting

### ImportError: No module named 'Pillow'

Install Pillow:
```bash
pip install Pillow>=10.0. Sprites appear0
```

### blurry in Godot

Ensure proper import settings in Godot:
1. Select the sprite texture
2. In Import settings, set **Filter** to **Nearest**
3. Disable **Mipmaps**
4. Click **Reimport**

### Wrong colors in game

Verify the sprite paths in your `.tres` files match the generated output structure. The migration script should handle this automatically.

## Related Documentation

- [Sprite Migration Plan](14_SPRITE_MIGRATION_PLAN_32x32.md) - Detailed migration phases
- [Main README](../README.md) - Project overview
