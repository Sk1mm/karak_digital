# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.7.2 |
| **Project Pinned** | 2026-10-07 |
| **LLM Knowledge Cutoff** | May 2025 (approx. Godot 4.3) |
| **Risk Level** | HIGH — version is beyond LLM training data |
| **Last Docs Verified** | 2026-10-07 |

## Post-Cutoff Version Timeline

| Version | Release (approx.) | Key Change |
|---------|-------------------|-----------|
| 4.4 | Early 2025 | @export_file → uid:// refs; store_* returns bool |
| 4.5 | Mid 2025 | RPC API renamed; StringName migration |
| 4.6 | Jan 2026 | Jolt default 3D physics; Quaternion init fix; glow change |
| 4.7 | Jun 2026 | HDR output; Control transforms; BlendSpace changes |
| 4.7.2 | Aug 2026 | Maintenance/bugfix release |

## Migration Guides

- 4.3 → 4.4: https://docs.godotengine.org/en/4.4/tutorials/migrating/upgrading_to_godot_4.4.html
- 4.4 → 4.5: https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.5 → 4.6: https://docs.godotengine.org/en/4.6/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.6 → 4.7: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

## Note for Agents

This project uses Godot 4.7.2, which is beyond the LLM's training data.
Before suggesting any API, verify against `breaking-changes.md` and `deprecated-apis.md`
in this directory. When uncertain about an API, use WebSearch to confirm against
the official Godot 4.7 documentation.
