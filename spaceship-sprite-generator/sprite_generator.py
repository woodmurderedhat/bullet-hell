"""
Spaceship Sprite Generator Module
Generates 32x32 pixel spaceship sprites for bullet hell game
"""

from PIL import Image, ImageDraw
import os
import math


# Color schemes for different enemy tiers
COLOR_SCHEMES = {
    'basic': {
        'primary': (64, 164, 223),      # Cyan-blue
        'secondary': (100, 200, 255),   # Light cyan
        'accent': (32, 100, 160),       # Darker blue
        'highlight': (150, 220, 255),  # Bright cyan
    },
    'medium': {
        'primary': (120, 200, 64),      # Green
        'secondary': (180, 230, 100),   # Light green
        'accent': (80, 150, 40),        # Dark green
        'highlight': (220, 255, 150),  # Bright yellow-green
    },
    'heavy': {
        'primary': (220, 100, 50),      # Orange
        'secondary': (255, 150, 80),    # Light orange
        'accent': (180, 60, 30),        # Dark red-orange
        'highlight': (255, 200, 100),   # Bright orange
    },
    'boss': {
        'primary': (160, 60, 180),      # Purple
        'secondary': (200, 100, 220),   # Light purple
        'accent': (100, 40, 120),       # Dark purple
        'highlight': (230, 150, 255),   # Bright magenta
    }
}

# Sprite dimensions
SPRITE_SIZE = 32
CENTER = SPRITE_SIZE // 2


def create_blank_image():
    """Create a blank 32x32 RGBA image with transparent background"""
    return Image.new('RGBA', (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))


def draw_triangular_ship(draw, x, y, size, direction='up', color=(255, 255, 255)):
    """Draw a triangular spaceship shape"""
    if direction == 'up':
        points = [
            (x, y - size),           # Top
            (x - size // 2, y + size // 2),  # Bottom left
            (x + size // 2, y + size // 2)  # Bottom right
        ]
    elif direction == 'down':
        points = [
            (x, y + size),
            (x - size // 2, y - size // 2),
            (x + size // 2, y - size // 2)
        ]
    elif direction == 'left':
        points = [
            (x - size, y),
            (x + size // 2, y - size // 2),
            (x + size // 2, y + size // 2)
        ]
    else:  # right
        points = [
            (x + size, y),
            (x - size // 2, y - size // 2),
            (x - size // 2, y + size // 2)
        ]
    draw.polygon(points, fill=color)


def draw_diamond_ship(draw, x, y, size, color=(255, 255, 255)):
    """Draw a diamond-shaped spaceship"""
    points = [
        (x, y - size),           # Top
        (x + size, y),           # Right
        (x, y + size),           # Bottom
        (x - size, y)            # Left
    ]
    draw.polygon(points, fill=color)


def draw_hexagon_ship(draw, x, y, size, color=(255, 255, 255)):
    """Draw a hexagonal spaceship"""
    points = []
    for i in range(6):
        angle = math.pi / 3 * i - math.pi / 2
        px = x + size * math.cos(angle)
        py = y + size * math.sin(angle)
        points.append((px, py))
    draw.polygon(points, fill=color)


def draw_wing_ship(draw, x, y, size, color=(255, 255, 255)):
    """Draw a spaceship with wings"""
    # Main body
    body_points = [
        (x, y - size),
        (x + size // 4, y),
        (x, y + size),
        (x - size // 4, y)
    ]
    draw.polygon(body_points, fill=color)
    
    # Left wing
    wing_left = [
        (x - size // 4, y - size // 4),
        (x - size, y + size // 4),
        (x - size // 4, y + size // 2)
    ]
    draw.polygon(wing_left, fill=color)
    
    # Right wing
    wing_right = [
        (x + size // 4, y - size // 4),
        (x + size, y + size // 4),
        (x + size // 4, y + size // 2)
    ]
    draw.polygon(wing_right, fill=color)


def draw_circular_ship(draw, x, y, radius, color=(255, 255, 255)):
    """Draw a circular spaceship"""
    draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color)


def add_details(draw, x, y, size, color, detail_type='dots'):
    """Add detail elements to the spaceship"""
    if detail_type == 'dots':
        # Add cockpit/details
        draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=color)
    elif detail_type == 'line':
        draw.line([x, y - size // 2, x, y + size // 2], fill=color, width=1)
    elif detail_type == 'rings':
        draw.ellipse([x - size // 2, y - size // 2, x + size // 2, y + size // 2], 
                     outline=color, width=1)


def generate_basic_ship(variant, colors, state='idle'):
    """Generate a basic enemy spaceship (small, simple)"""
    img = create_blank_image()
    draw = ImageDraw.Draw(img)
    
    color = colors['primary']
    accent = colors['accent']
    
    if variant == 1:
        # Simple triangle
        draw_triangular_ship(draw, CENTER, CENTER, 10, 'up', color)
        add_details(draw, CENTER, CENTER - 2, 10, colors['highlight'], 'dots')
    elif variant == 2:
        # Small diamond
        draw_diamond_ship(draw, CENTER, CENTER, 8, color)
        draw.polygon([(CENTER, CENTER - 10), (CENTER + 3, CENTER - 6), (CENTER, CENTER - 4)], fill=colors['highlight'])
    elif variant == 3:
        # Arrow shape
        points = [(CENTER, CENTER - 10), (CENTER + 8, CENTER + 6), (CENTER, CENTER + 2), (CENTER - 8, CENTER + 6)]
        draw.polygon(points, fill=color)
    elif variant == 4:
        # Inverted triangle with wings
        draw_triangular_ship(draw, CENTER, CENTER + 2, 8, 'down', color)
        draw.polygon([(CENTER - 6, CENTER - 2), (CENTER - 10, CENTER + 6), (CENTER - 4, CENTER + 6)], fill=accent)
        draw.polygon([(CENTER + 6, CENTER - 2), (CENTER + 10, CENTER + 6), (CENTER + 4, CENTER + 6)], fill=accent)
    elif variant == 5:
        # Small circular with points
        draw_circular_ship(draw, CENTER, CENTER, 7, color)
        draw.polygon([(CENTER - 7, CENTER), (CENTER - 10, CENTER - 3), (CENTER - 10, CENTER + 3)], fill=accent)
        draw.polygon([(CENTER + 7, CENTER), (CENTER + 10, CENTER - 3), (CENTER + 10, CENTER + 3)], fill=accent)
    
    # Apply state modifications
    if state == 'move':
        # Add thruster flame
        draw.polygon([(CENTER - 3, CENTER + 10), (CENTER, CENTER + 14), (CENTER + 3, CENTER + 10)], 
                     fill=colors['highlight'])
    elif state == 'hit':
        # Add flash effect
        overlay = Image.new('RGBA', (SPRITE_SIZE, SPRITE_SIZE), (255, 255, 255, 80))
        img = Image.alpha_composite(img, overlay)
    elif state == 'death':
        # Add explosion particles
        draw = ImageDraw.Draw(img)
        for i in range(8):
            angle = math.pi / 4 * i
            px = CENTER + int(8 * math.cos(angle))
            py = CENTER + int(8 * math.sin(angle))
            draw.ellipse([px - 2, py - 2, px + 2, py + 2], fill=colors['highlight'])
    
    return img


def generate_medium_ship(variant, colors, state='idle'):
    """Generate a medium enemy spaceship (more complex)"""
    img = create_blank_image()
    draw = ImageDraw.Draw(img)
    
    color = colors['primary']
    accent = colors['accent']
    secondary = colors['secondary']
    
    if variant == 1:
        # Winged triangle
        draw_triangular_ship(draw, CENTER, CENTER, 10, 'up', color)
        # Wings
        draw.polygon([(CENTER - 8, CENTER), (CENTER - 12, CENTER + 4), (CENTER - 6, CENTER + 4)], fill=accent)
        draw.polygon([(CENTER + 8, CENTER), (CENTER + 12, CENTER + 4), (CENTER + 6, CENTER + 4)], fill=accent)
        # Cockpit
        draw.ellipse([CENTER - 2, CENTER - 4, CENTER + 2, CENTER], fill=colors['highlight'])
    elif variant == 2:
        # Hexagonal with details
        draw_hexagon_ship(draw, CENTER, CENTER, 9, color)
        draw.ellipse([CENTER - 3, CENTER - 3, CENTER + 3, CENTER + 3], fill=accent)
        draw.ellipse([CENTER - 1, CENTER - 1, CENTER + 1, CENTER + 1], fill=colors['highlight'])
    elif variant == 3:
        # Diamond with wings
        draw_diamond_ship(draw, CENTER, CENTER, 9, color)
        draw.polygon([(CENTER - 6, CENTER - 2), (CENTER - 12, CENTER - 2), (CENTER - 8, CENTER + 4)], fill=accent)
        draw.polygon([(CENTER + 6, CENTER - 2), (CENTER + 12, CENTER - 2), (CENTER + 8, CENTER + 4)], fill=accent)
        # Center line
        draw.line([CENTER, CENTER - 8, CENTER, CENTER + 8], fill=colors['highlight'], width=2)
    elif variant == 4:
        # Complex angular
        points = [
            (CENTER, CENTER - 12),
            (CENTER + 10, CENTER - 4),
            (CENTER + 8, CENTER + 6),
            (CENTER, CENTER + 10),
            (CENTER - 8, CENTER + 6),
            (CENTER - 10, CENTER - 4)
        ]
        draw.polygon(points, fill=color)
        # Inner detail
        draw.polygon([
            (CENTER, CENTER - 6),
            (CENTER + 4, CENTER),
            (CENTER, CENTER + 4),
            (CENTER - 4, CENTER)
        ], fill=secondary)
    
    # Apply state modifications
    if state == 'move':
        # Double thruster flames
        draw.polygon([(CENTER - 4, CENTER + 10), (CENTER - 2, CENTER + 15), (CENTER, CENTER + 12)], fill=colors['highlight'])
        draw.polygon([(CENTER + 4, CENTER + 10), (CENTER + 2, CENTER + 15), (CENTER, CENTER + 12)], fill=colors['highlight'])
    elif state == 'hit':
        overlay = Image.new('RGBA', (SPRITE_SIZE, SPRITE_SIZE), (255, 255, 255, 80))
        img = Image.alpha_composite(img, overlay)
    elif state == 'death':
        for i in range(12):
            angle = math.pi / 6 * i
            px = CENTER + int(10 * math.cos(angle))
            py = CENTER + int(10 * math.sin(angle))
            draw.ellipse([px - 3, py - 3, px + 3, py + 3], fill=colors['highlight'])
    
    return img


def generate_heavy_ship(variant, colors, state='idle'):
    """Generate a heavy enemy spaceship (larger, detailed)"""
    img = create_blank_image()
    draw = ImageDraw.Draw(img)
    
    color = colors['primary']
    accent = colors['accent']
    secondary = colors['secondary']
    
    if variant == 1:
        # Bulky angular
        points = [
            (CENTER, CENTER - 14),
            (CENTER + 12, CENTER - 6),
            (CENTER + 14, CENTER + 4),
            (CENTER + 10, CENTER + 12),
            (CENTER, CENTER + 14),
            (CENTER - 10, CENTER + 12),
            (CENTER - 14, CENTER + 4),
            (CENTER - 12, CENTER - 6)
        ]
        draw.polygon(points, fill=color)
        # Detail panels
        draw.polygon([(CENTER - 6, CENTER - 4), (CENTER + 6, CENTER - 4), (CENTER + 4, CENTER + 4), (CENTER - 4, CENTER + 4)], fill=accent)
        draw.ellipse([CENTER - 2, CENTER - 2, CENTER + 2, CENTER + 2], fill=colors['highlight'])
    elif variant == 2:
        # Heavy cruiser
        # Main body
        draw.polygon([(CENTER, CENTER - 14), (CENTER + 8, CENTER + 8), (CENTER, CENTER + 12), (CENTER - 8, CENTER + 8)], fill=color)
        # Wings
        draw.polygon([(CENTER - 8, CENTER - 2), (CENTER - 14, CENTER + 8), (CENTER - 8, CENTER + 10)], fill=accent)
        draw.polygon([(CENTER + 8, CENTER - 2), (CENTER + 14, CENTER + 8), (CENTER + 8, CENTER + 10)], fill=accent)
        # Cannons
        draw.rectangle([CENTER - 10, CENTER + 4, CENTER - 8, CENTER + 10], fill=secondary)
        draw.rectangle([CENTER + 8, CENTER + 4, CENTER + 10, CENTER + 10], fill=secondary)
    elif variant == 3:
        # Octagonal tank
        points = []
        for i in range(8):
            angle = math.pi / 4 * i - math.pi / 8
            radius = 12 if i % 2 == 0 else 10
            px = CENTER + radius * math.cos(angle)
            py = CENTER + radius * math.sin(angle)
            points.append((px, py))
        draw.polygon(points, fill=color)
        # Inner ring
        draw.ellipse([CENTER - 5, CENTER - 5, CENTER + 5, CENTER + 5], fill=accent)
        draw.ellipse([CENTER - 2, CENTER - 2, CENTER + 2, CENTER + 2], fill=colors['highlight'])
    
    # Apply state modifications
    if state == 'move':
        # Large thrusters
        draw.polygon([(CENTER - 6, CENTER + 12), (CENTER - 4, CENTER + 16), (CENTER, CENTER + 14)], fill=colors['highlight'])
        draw.polygon([(CENTER + 6, CENTER + 12), (CENTER + 4, CENTER + 16), (CENTER, CENTER + 14)], fill=colors['highlight'])
        draw.polygon([(CENTER - 10, CENTER + 8), (CENTER - 12, CENTER + 14), (CENTER - 8, CENTER + 12)], fill=secondary)
        draw.polygon([(CENTER + 10, CENTER + 8), (CENTER + 12, CENTER + 14), (CENTER + 8, CENTER + 12)], fill=secondary)
    elif state == 'hit':
        overlay = Image.new('RGBA', (SPRITE_SIZE, SPRITE_SIZE), (255, 255, 255, 80))
        img = Image.alpha_composite(img, overlay)
    elif state == 'death':
        for i in range(16):
            angle = math.pi / 8 * i
            px = CENTER + int(12 * math.cos(angle))
            py = CENTER + int(12 * math.sin(angle))
            size = 4 if i % 2 == 0 else 2
            draw.ellipse([px - size, py - size, px + size, py + size], fill=colors['highlight'])
    
    return img


def generate_boss_ship(variant, colors, state='idle'):
    """Generate a boss spaceship (largest, most detailed)"""
    img = create_blank_image()
    draw = ImageDraw.Draw(img)
    
    color = colors['primary']
    accent = colors['accent']
    secondary = colors['secondary']
    
    if variant == 1:
        # Dreadnought - massive angular design
        # Central hull
        points = [
            (CENTER, CENTER - 15),
            (CENTER + 10, CENTER - 10),
            (CENTER + 14, CENTER),
            (CENTER + 14, CENTER + 8),
            (CENTER + 8, CENTER + 14),
            (CENTER, CENTER + 15),
            (CENTER - 8, CENTER + 14),
            (CENTER - 14, CENTER + 8),
            (CENTER - 14, CENTER),
            (CENTER - 10, CENTER - 10)
        ]
        draw.polygon(points, fill=color)
        # Wings
        draw.polygon([(CENTER - 10, CENTER - 6), (CENTER - 15, CENTER + 2), (CENTER - 12, CENTER + 10), (CENTER - 6, CENTER + 6)], fill=accent)
        draw.polygon([(CENTER + 10, CENTER - 6), (CENTER + 15, CENTER + 2), (CENTER + 12, CENTER + 10), (CENTER + 6, CENTER + 6)], fill=accent)
        # Details
        draw.ellipse([CENTER - 4, CENTER - 4, CENTER + 4, CENTER + 4], fill=accent)
        draw.ellipse([CENTER - 2, CENTER - 2, CENTER + 2, CENTER + 2], fill=colors['highlight'])
        # Side cannons
        draw.rectangle([CENTER - 15, CENTER, CENTER - 12, CENTER + 6], fill=secondary)
        draw.rectangle([CENTER + 12, CENTER, CENTER + 15, CENTER + 6], fill=secondary)
    elif variant == 2:
        # Carrier - elongated design
        # Main body
        draw.polygon([(CENTER, CENTER - 15), (CENTER + 6, CENTER - 12), (CENTER + 8, CENTER + 12), (CENTER, CENTER + 15), (CENTER - 8, CENTER + 12), (CENTER - 6, CENTER - 12)], fill=color)
        # Engine pods
        draw.polygon([(CENTER - 8, CENTER + 8), (CENTER - 12, CENTER + 12), (CENTER - 6, CENTER + 14)], fill=accent)
        draw.polygon([(CENTER + 8, CENTER + 8), (CENTER + 12, CENTER + 12), (CENTER + 6, CENTER + 14)], fill=accent)
        # Wings
        draw.polygon([(CENTER - 6, CENTER - 4), (CENTER - 14, CENTER), (CENTER - 10, CENTER + 8), (CENTER - 4, CENTER + 4)], fill=accent)
        draw.polygon([(CENTER + 6, CENTER - 4), (CENTER + 14, CENTER), (CENTER + 10, CENTER + 8), (CENTER + 4, CENTER + 4)], fill=accent)
        # Bridge
        draw.ellipse([CENTER - 3, CENTER - 8, CENTER + 3, CENTER - 2], fill=secondary)
        draw.ellipse([CENTER - 1, CENTER - 6, CENTER + 1, CENTER - 4], fill=colors['highlight'])
    
    # Apply state modifications
    if state == 'move':
        # Multiple thrusters
        draw.polygon([(CENTER, CENTER + 14), (CENTER - 2, CENTER + 16), (CENTER + 2, CENTER + 16)], fill=colors['highlight'])
        draw.polygon([(CENTER - 6, CENTER + 12), (CENTER - 8, CENTER + 16), (CENTER - 4, CENTER + 16)], fill=secondary)
        draw.polygon([(CENTER + 6, CENTER + 12), (CENTER + 8, CENTER + 16), (CENTER + 4, CENTER + 16)], fill=secondary)
        draw.polygon([(CENTER - 12, CENTER + 10), (CENTER - 14, CENTER + 14), (CENTER - 10, CENTER + 14)], fill=colors['highlight'])
        draw.polygon([(CENTER + 12, CENTER + 10), (CENTER + 14, CENTER + 14), (CENTER + 10, CENTER + 14)], fill=colors['highlight'])
    elif state == 'hit':
        overlay = Image.new('RGBA', (SPRITE_SIZE, SPRITE_SIZE), (255, 255, 255, 80))
        img = Image.alpha_composite(img, overlay)
    elif state == 'death':
        # Massive explosion
        for i in range(20):
            angle = math.pi / 10 * i
            px = CENTER + int(14 * math.cos(angle))
            py = CENTER + int(14 * math.sin(angle))
            size = 5 if i % 3 == 0 else 3
            draw.ellipse([px - size, py - size, px + size, py + size], fill=colors['highlight'])
    
    return img


def generate_sprite(enemy_type, variant, state='idle'):
    """Generate a spaceship sprite based on type and variant"""
    if enemy_type == 'basic':
        colors = COLOR_SCHEMES['basic']
        return generate_basic_ship(variant, colors, state)
    elif enemy_type == 'medium':
        colors = COLOR_SCHEMES['medium']
        return generate_medium_ship(variant, colors, state)
    elif enemy_type == 'heavy':
        colors = COLOR_SCHEMES['heavy']
        return generate_heavy_ship(variant, colors, state)
    elif enemy_type == 'boss':
        colors = COLOR_SCHEMES['boss']
        return generate_boss_ship(variant, colors, state)
    else:
        raise ValueError(f"Unknown enemy type: {enemy_type}")


def save_sprite(img, output_dir, domain, entity, state):
    """Save sprite to the appropriate directory"""
    # Create directory structure: sprites/{domain}/{entity}/
    dir_path = os.path.join(output_dir, 'sprites', domain, entity)
    os.makedirs(dir_path, exist_ok=True)
    
    # Save as {entity}_{state}.png
    filename = f"{entity}_{state}.png"
    filepath = os.path.join(dir_path, filename)
    img.save(filepath)
    print(f"Saved: {filepath}")
    return filepath


def generate_all_sprites(output_dir='.'):
    """Generate all spaceship sprites"""
    states = ['idle', 'move', 'hit', 'death']
    
    # Basic enemies - 5 variants
    print("Generating Basic Enemies...")
    for variant in range(1, 6):
        for state in states:
            img = generate_sprite('basic', variant, state)
            entity_name = f"basic_{variant}"
            save_sprite(img, output_dir, 'enemies', entity_name, state)
    
    # Medium enemies - 4 variants
    print("\nGenerating Medium Enemies...")
    for variant in range(1, 5):
        for state in states:
            img = generate_sprite('medium', variant, state)
            entity_name = f"medium_{variant}"
            save_sprite(img, output_dir, 'enemies', entity_name, state)
    
    # Heavy enemies - 3 variants
    print("\nGenerating Heavy Enemies...")
    for variant in range(1, 4):
        for state in states:
            img = generate_sprite('heavy', variant, state)
            entity_name = f"heavy_{variant}"
            save_sprite(img, output_dir, 'enemies', entity_name, state)
    
    # Bosses - 2 variants
    print("\nGenerating Bosses...")
    for variant in range(1, 3):
        for state in states:
            img = generate_sprite('boss', variant, state)
            entity_name = f"boss_{variant}"
            save_sprite(img, output_dir, 'bosses', entity_name, state)
    
    print("\nAll sprites generated successfully!")


if __name__ == '__main__':
    generate_all_sprites()
