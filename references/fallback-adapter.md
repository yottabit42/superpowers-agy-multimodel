# 3-Phase Missing-Subagent Fallback Adapter

Use this adapter whenever `invoke_subagent` fails with `"subagent not found or not allowed"` (for example, in an Antigravity IDE session where plugin-bundled `agents/` discovery did not fire).

Never pass `"pro"` to `Model` in any phase; use only `"flash"` or `"inherit"` according to the active `quota`/`same` profile.

---

## Phase 1: Runtime `define_subagent` Registration

1. Read the bundled `agents/<role>.md` file via `view_file` (or `read_file`).
2. Extract the `description` field from YAML frontmatter and strip the YAML frontmatter block (`--- ... ---`) to obtain the Markdown system prompt body.
3. Call `define_subagent` matching the active session's tool schema:
   - **PascalCase schema (current Cortex / CLI):**
     `define_subagent(Name: "<role>", Description: "<desc>", SystemPrompt: "<body>", EnableWriteTools: <bool>, EnableMCPTools: false, EnableSubagentTools: false)`
   - **snake_case schema (older IDE builds):**
     `define_subagent(name: "<role>", description: "<desc>", system_prompt: "<body>", enable_write_tools: <bool>, enable_mcp_tools: false, enable_subagent_tools: false)`
   - Set `EnableWriteTools` / `enable_write_tools` to `true` for roles that write files or execute test suites via `run_command` (`implementer`, `planner`, `codesigner`, `designdoc-drafter`, `skills-implementer`, `verifier`, `spec-reviewer`, `code-reviewer`, `re-reviewer`), and `false` for pure file/web readers (`architect`, `research-flash`, `skills-devils-advocate` when `run_command` is not needed). Always keep `EnableSubagentTools: false` (`enable_subagent_tools: false`) so leaf workers never spawn nested subagents.
4. Retry `invoke_subagent` with `TypeName: "<role>"` (passing `Model: "flash"` or `Model: "inherit"` if `Model` is declared on `invoke_subagent`) and the `[ROLE: <role>]` + `<SUBAGENT-STOP>` handoff envelope.

---

## Phase 2: `TypeName: "self"` Leaf Override

If `define_subagent` is unavailable or fails:

1. Read `agents/<role>.md` and strip its YAML frontmatter.
2. Call `invoke_subagent` with `TypeName: "self"`, `Role: "<role>"`, `Workspace: "<inherit|branch|share>"`, and `Model: "<flash|inherit>"` (if `Model` is declared on `invoke_subagent`; always `"flash"` for execution/verification roles under `profile=quota`).
3. Prepend `<SUBAGENT-STOP>`, the stripped `agents/<role>.md` system prompt body, and the hermetic `[ROLE: <role>]` envelope to `Prompt`:

```markdown
[ROLE: <role>]
<SUBAGENT-STOP>
<stripped agents/<role>.md system prompt body>

GOAL: <one-sentence engineering objective>
TASK: <full self-contained task text, commit range, or audit brief>
SCOPE: <exact file paths owned or inspected>
CONTEXT: <Global Constraints, interface contracts, ledger rulings>
CONSTRAINTS: Workspace=<inherit|branch|share>; leaf worker only (never invoke subagents); read <= 10 files / <= 150 KB per turn
VERIFICATION: <exact project test/lint commands or read-only inspection rules>
SKILLS: <optional leaf SKILL.md paths>
```

---

## Phase 3: Inline Leaf Execution

If `invoke_subagent` itself is unavailable in the current environment:

1. Read `agents/<role>.md` and adopt its `<SUBAGENT-STOP>` leaf contract inline for that step.
2. Execute the role's workflow sequentially in the current context without skipping any verification or review gate.
3. Record `Ruling: <role> executed inline via Phase 3 fallback — invoke_subagent unavailable` in the active ledger (or chat if no ledger is open).
