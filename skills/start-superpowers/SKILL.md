---
name: start-superpowers
description: Use when switching Superpowers orchestration mode (auto, solo, subagents) or model-routing profile (quota, same) for the current session or workspace config
---

# Start Superpowers Mode & Profile Switch

Parse optional `[auto|solo|subagents]` and `[quota|same]` arguments from your human partner's command:
- Default `mode`: `auto` (allows Route 1 Direct IC on `<= 2` coupled files; delegates Tier 2/3).
- Default `profile`: `quota` (routes execution/verification roles to `flash` and judgment roles to `inherit`; `same` routes all roles to `inherit`).

## Actions

1. Apply the selected `mode` and `profile` as the highest-precedence session override.
2. Only if your human partner explicitly asks to persist the setting, write `<repo-root>/.superpowers/config.json` (`default_mode`, `default_profile`, `max_concurrent_inherit: 8`) and ensure `<repo-root>/.superpowers/.gitignore` contains `*` (or update `~/.gemini/superpowers_config.json` when requested globally).
3. Confirm active settings in one line: `Superpowers active: mode=<mode>, profile=<profile> (max_concurrent_inherit=8).` and follow `skills/using-superpowers/SKILL.md`.
