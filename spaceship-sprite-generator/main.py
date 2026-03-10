#!/usr/bin/env python3
"""
Spaceship Sprite Generator - Main Entry Point
Generates 32x32 pixel spaceship sprites for bullet hell game
"""

import os
import sys

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sprite_generator import generate_all_sprites


def main():
    """Main entry point for the sprite generator"""
    # Get the directory where the script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("=" * 60)
    print("  SPACESHIP SPRITE GENERATOR")
    print("  32x32 Pixel Art for Bullet Hell Game")
    print("=" * 60)
    print()
    
    # Generate all sprites in the script directory
    generate_all_sprites(script_dir)
    
    print()
    print("=" * 60)
    print("  GENERATION COMPLETE!")
    print("=" * 60)
    print()
    print("Output structure:")
    print("  sprites/")
    print("  ├── enemies/")
    print("  │   ├── basic/")
    print("  │   │   ├── basic_1_idle.png")
    print("  │   │   ├── basic_1_move.png")
    print("  │   │   ├── basic_1_hit.png")
    print("  │   │   ├── basic_1_death.png")
    print("  │   │   └── ... (5 variants × 4 states)")
    print("  │   ├── medium/")
    print("  │   │   └── ... (4 variants × 4 states)")
    print("  │   └── heavy/")
    print("  │       └── ... (3 variants × 4 states)")
    print("  └── bosses/")
    print("      └── ... (2 variants × 4 states)")
    print()
    print("Color schemes:")
    print("  - Basic:   Blues/Cyans (weaker enemies)")
    print("  - Medium:  Greens/Yellows (mid-tier)")
    print("  - Heavy:   Oranges/Reds (tough enemies)")
    print("  - Bosses:  Purples/Magentas (bosses)")
    print()


if __name__ == '__main__':
    main()
