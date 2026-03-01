# Performance Specification

Target: Raspberry Pi 5 (ARM64)
Resolution: 1280x720
Target FPS: 60

Hard Caps:
- Bullets: 4000
- Enemies: 150
- Effects: 300

Rules:
- No allocations in hot loops
- No per-bullet signals
- Use pooling
- Manual collision checks