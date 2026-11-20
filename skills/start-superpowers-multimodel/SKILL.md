---
name: start-superpowers-multimodel
description: Use when activating strict 100% delegated multi-model orchestration (/start-superpowers-multimodel) with quota-saving flash execution and inherited reasoning
---

# Start Superpowers Multi-Model (Strict Delegation)

Activate `mode=subagents` and `profile=quota` (`max_concurrent_inherit=8`) as the active session override (equivalent to `/start-superpowers subagents quota`).

## Actions

1. Bypass Route 1 Direct IC Mode for code mutations: delegate even surgical edits to `implementer` on `flash` (`Model: "flash"` or `TypeName: "implementer-flash"` when `Model` is absent from `invoke_subagent`).
2. Only if your human partner explicitly asks to persist the setting, write `{"default_mode": "subagents", "default_profile": "quota", "max_concurrent_inherit": 8}` to `.superpowers/config.json` (with `.superpowers/.gitignore` set to `*`).
3. Confirm in one line: `Superpowers Multi-Model active: mode=subagents, profile=quota (max_concurrent_inherit=8).` and follow `skills/using-superpowers/SKILL.md`.
