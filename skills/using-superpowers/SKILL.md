---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task (including whenever your prompt starts with `[ROLE:` or `<SUBAGENT-STOP>`, or when `invoke_subagent` is absent from your active tool declarations), operate strictly as a leaf worker: ignore the orchestrator routing rules in this skill, never spawn subagents, and execute your assigned task directly.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out. Brainstorming and systematic-debugging are Superpowers' most common process skills, but the rule holds for any of them.

- "Let's build X" → superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

## Step-0 Adaptive Router & Host Yield

**Host Yield:** If the prompt or system context invokes `/swarm`, `/teamwork-preview` (`<TEAMWORK>`), or `/browser` (`<SUBAGENT>`), yield to that built-in host (including inside swarm workers). Apply Superpowers TDD, debugging, and verification skills as leaf discipline without running a competing Step-0 router or wrapping built-in host dispatches in `[ROLE:]` envelopes.

On the first response to a new engineering task, classify the route (first match wins) and announce one line:
`Route: <N> (<mode>) — <reason> [Profile: <quota|same>]`

| Route | Trigger Condition | Execution Topology (`quota` profile) |
|---|---|---|
| **Route 0: Explicit Override** | Partner invokes `/start-superpowers [mode] [profile]`, `/start-superpowers-multimodel`, or asks to spawn subagents. | Apply requested `mode` and `profile`. If `mode=subagents` or subagents were requested, bypass Route 1. |
| **Route 1: Tier 1 Surgical (Direct IC)** | `mode` is `auto` or `solo`, and task is read-only Q&A, lookup, or surgical edit (`<= 2` coupled files, `< 150` lines, known cause). | Execute directly in main context (after `brainstorming` bounded approval if creative/behavioral). Run project tests directly. Escalate to Route 4 if `> 2` files change or tests fail. *(If `mode=subagents`, dispatch `1x implementer` on `flash`.)* |
| **Route 2: Open Survey (`9+` Files)** | Broad codebase exploration across `9+` files or unfamiliar architecture. | Dispatch `1x architect` (`inherit`) + sharded `research` (`flash` / `research-flash`, max 10 files or 150 KB per shard). |
| **Route 3: Persistent Bug (`>= 2` Failed Fixes)** | Bug survives `>= 2` fix attempts or involves race/state corruption. | Follow `systematic-debugging` Phase 1. Dispatch `implementer` (`flash` on attempt 1; escalate to `inherit` if a `flash` implementer already failed). |
| **Route 4: Tier 2 Coupled Feature (`3–8` Files)** | Settled design touching `3–8` coupled files. | `1x planner` (`flash`, if no plan exists) → per-task `1x implementer` (`flash`) → `1x spec-reviewer` (`flash`) → `1x code-reviewer` (`flash`) → whole-branch `1x code-reviewer` (`inherit`) + `1x verifier` (`flash`). |
| **Route 5: Tier 3 Architectural / Cross-Package** | Cross-package refactor, interface/schema migration, or security-critical change. | **Best-of-N:** `1x architect` (`inherit`) → `2x planner` (`inherit`, parallel) → synthesize unified plan → per-task `1x implementer` (`flash`, max 3 tasks or 8 files per batch) → `1x spec-reviewer` (`flash`) → parallel `2x code-reviewer` (`1x inherit` lead + `1x flash` secondary) → `1x verifier` (`flash`). |
| **Route 6: Disjoint Parallel Domains (`3+` Slices)** | `3+` independent test failures, subsystems, or mechanical file shards with zero shared state. | Use `dispatching-parallel-agents`: dispatch `implementer` (`flash` / `implementer-flash`) per slice with `Workspace: "share"` → `1x verifier` (`flash`) on merged result. |
| **Route 7: Human-Gated Design, Plan, or Skill** | Underspecified feature, `/design`, `/plan`, or `writing-skills` request. | **Design:** foreground Q&A + `generate_image` in main context → `1x codesigner` (`inherit`) critique & handoff → `1x designdoc-drafter` (`flash`) drafts spec → review gate. **Plan:** Tier 2 `1x planner` (`flash`) or Tier 3 `architect` + `2x planner` (`inherit`). **Skills:** `1x skills-implementer` (`inherit`) → `1x skills-devils-advocate` (`inherit`). |

## Multi-Model Routing (`quota` vs `same`)

**Config Precedence Cascade (Highest to Lowest):**
1. Session command: `/start-superpowers [auto|solo|subagents] [quota|same]` or `/start-superpowers-multimodel` (`mode=subagents`, `profile=quota`).
2. Workspace config: `<repo-root>/.superpowers/config.json`.
3. Global config: `~/.gemini/superpowers_config.json`.
4. Built-in defaults: `default_mode: "auto"`, `default_profile: "quota"`, `max_concurrent_inherit: 2`, `role_models` overrides.

**Canonical Role Routing Matrix:**

| Subagent `TypeName` | IDE Flash Variant (`hidden: true`) | `quota` Tier | `same` Tier | `Workspace` |
|---|---|---|---|---|
| `architect` | *(uses `research-flash` on 429)* | `inherit` | `inherit` | `"inherit"` |
| `codesigner` | *(foreground fallback on 429)* | `inherit` | `inherit` | `"inherit"` |
| `designdoc-drafter` | `designdoc-drafter-flash` | `flash` | `inherit` | `"inherit"` |
| `planner` | `planner-flash` | Tier 2: `flash` · Tier 3 / `/plan`: `inherit` | `inherit` | `"inherit"` |
| `implementer` | `implementer-flash` | Rounds 1–3: `flash` · `BLOCKED` / Rounds 4–5: `inherit` | `inherit` | `"branch"` (SDD) / `"share"` (parallel) |
| `spec-reviewer` | `spec-reviewer-flash` | `flash` | `inherit` | `"inherit"` |
| `code-reviewer` | `code-reviewer-flash` | Tier 2 task & Tier 3 secondary: `flash` · Tier 3 lead & final branch: `inherit` | `inherit` | `"inherit"` |
| `re-reviewer` | `re-reviewer-flash` | `flash` | `inherit` | `"inherit"` |
| `verifier` | `verifier-flash` | `flash` | `inherit` | `"inherit"` |
| `skills-implementer` | *(foreground fallback on 429)* | `inherit` | `inherit` | `"branch"` |
| `skills-devils-advocate` | *(uses `code-reviewer-flash` on 429)* | `inherit` | `inherit` | `"inherit"` |
| `research` *(built-in)* | `research-flash` | `flash` | `inherit` | `"inherit"` |

**Hybrid Model-Resolution & Quota Guardrails:**
1. **Inspect `invoke_subagent` schema:**
   - **If `Model` is declared on `invoke_subagent`:** Dispatch primary `TypeName: "<role>"` with `Model: "flash"` or `Model: "inherit"`. Match the active `invoke_subagent` parameter shape (flat `{TypeName, Role, Prompt, Model, Workspace}` or `Subagents: [{...}]` array).
   - **If `Model` is absent from `invoke_subagent`:** For `inherit`, dispatch primary `TypeName: "<role>"` (omitted `model:` defaults to `inherit`). For `flash`, dispatch `TypeName: "<role>-flash"` (or `research-flash` for `research`), whose frontmatter forces `model: flash`.
2. **Quota Guardrails:** Never pass `"pro"` to `Model`. Cap concurrent `inherit` subagents at `max_concurrent_inherit: 2` (batch into waves of at most 2). On `429 RESOURCE_EXHAUSTED` or capacity timeout on an `inherit` subagent, record `Ruling: <role> downgraded inherit → flash due to 429/capacity — <risk>` in the ledger (or chat) and retry immediately on `flash`.
3. **Hermetic `[ROLE: <role>]` Handoff Envelope:** Begin every specialist subagent prompt with `[ROLE: <role-name>]` + `<SUBAGENT-STOP>` followed by `GOAL`, `TASK`, `SCOPE`, `CONTEXT`, `CONSTRAINTS`, `VERIFICATION`, and optional leaf `SKILLS`.
4. **Missing-Subagent Fallback:** If `invoke_subagent` fails with `"subagent not found or not allowed"`, follow `references/fallback-adapter.md` (Phase 1 `define_subagent` → Phase 2 `TypeName: "self"` leaf override → Phase 3 inline leaf execution).

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## User Instructions

User instructions (GEMINI.md, AGENTS.md, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
