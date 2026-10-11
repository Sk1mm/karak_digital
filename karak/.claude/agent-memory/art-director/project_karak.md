---
name: Project — Karak Digital visual context
description: Core visual identity, art direction status, and key design decisions for Karak Digital
type: project
---

Game: Karak Digital — 2D top-down dungeon crawler board game for PC.
Visual identity anchor: "Storybook Dungeon" — bold friendly outlines, warm dungeon lighting. Scary but safe, children's adventure book illustration aesthetic.
Three visual principles: (1) readability first — high contrast for 6-year-old legibility, (2) cartoon monsters — scary but not frightening (Clash Royale level), (3) visual weight of loot — items look impactful.
Color philosophy: dark blues/grays for dungeon + warm gold/orange accents for loot and rewards.
Target audience: parents with children age 5-10. Hotseat 2-5 players. PC only.
Rendering: Godot Compatibility Renderer 2D.

**Why:** Personal project, father playing with young son — warmth and safety are non-negotiable aesthetic constraints.
**How to apply:** Every visual decision must pass the "child laughs, not fears" test. Readability over atmosphere whenever there is tension between the two.

Art status as of 2026-10-11:
- Visual Identity Anchor documented in design/gdd/game-concept.md (approved)
- design/art/art-bible.md does NOT exist
- Multiple GDDs reference art-bible as a future dependency (hud.md, combat-ui.md, tile-reveal-vfx.md, inventory-ui.md)
- Several color values are hardcoded in GDDs as placeholders pending art-bible (e.g., inventory-ui badge colors, combat-ui backdrop #0D0D1A)
- Font decisions are explicitly deferred to art-bible creation (OQ-CUI-05 in combat-ui.md)
- No asset specs, no character visual profiles, no UI visual specs exist yet
