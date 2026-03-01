---
name: project-overview
description: "High-level guidance for architectural decisions, system design, and interactions in the Polychrome Void project."
license: "MIT"
---
When responding to questions about project architecture, inter-system dependencies, data flows, or cross-module contracts:

1. Reference the official project GDD, TDD, performance and progression docs.
2. Describe modular responsibilities of systems like BulletManager, SpawnDirector, EventBus, and ModifierComponent.
3. Provide reasoning for design choices in context of poor performance on hardware targets like Raspberry Pi 5.
4. Avoid printing full file headers or auto-generated boilerplate unless explicitly requested.
5. Provide pseudo-code snippets when helpful.
