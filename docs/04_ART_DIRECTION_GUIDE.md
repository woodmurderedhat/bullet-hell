# Art Direction Guide

Style: Abstract Geometric Minimalism

Shapes:
- Player: Triangle
- Enemy: Square
- Boss: Polygon
- Player bullets: Lines
- Enemy bullets: Circles

Rules:
- No gradients
- High contrast colors
- Black background

## 2026 Sprite Migration Exception

For the core actor set only (Player, Enemy, Boss), 32x32 pixel sprites are now allowed.

Constraints for this exception:
- Preserve abstract geometric silhouettes and readable shape language.
- Keep bullets on current non-sprite rendering path for performance.
- Use nearest-neighbor pixel presentation (no filtering blur).
- Treat sprite size as visual only; collision radii remain gameplay-authoritative.
- Avoid detailed texture noise that reduces readability at 1280x720.