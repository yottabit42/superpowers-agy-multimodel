#!/usr/bin/env bash
# Static verification suite for v7.0.0 multi-model orchestration invariants.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MODE="${1:---all}"
SUBMODE="${2:-all}"
FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

check_no_pro() {
  local target="$1"
  if [ -e "$REPO_ROOT/$target" ] && grep -rnE 'Model:[[:space:]]*"pro"|^model:[[:space:]]*pro([[:space:]]|$)' "$REPO_ROOT/$target" >/dev/null 2>&1; then
    fail "Banned pro model tier found in $target"
  else
    pass "Zero pro model tier in $target"
  fi
}

run_specs() {
  echo "=== Gate: Platform & Design Specs ==="
  local spec="$REPO_ROOT/docs/superpowers/specs/2026-11-04-multimodel-orchestrator-design.md"
  local plan="$REPO_ROOT/docs/superpowers/plans/2026-11-04-multimodel-orchestrator.md"
  local ref="$REPO_ROOT/docs/superpowers/specs/2026-07-29-antigravity-2-0-platform-reference.md"
  [ -s "$spec" ] && pass "Design spec exists" || fail "Missing $spec"
  [ -s "$plan" ] && pass "Implementation plan exists" || fail "Missing $plan"
  for tok in "MODEL_TIER_UNSPECIFIED" "hidden" "always_inherit_model" "EnableWriteTools"; do
    if grep -Fq "$tok" "$ref" 2>/dev/null; then
      pass "Platform reference documents $tok"
    else
      fail "Platform reference missing $tok"
    fi
  done
}

run_fallback() {
  echo "=== Gate: 3-Phase Fallback Adapter ==="
  local fb="$REPO_ROOT/references/fallback-adapter.md"
  if [ ! -s "$fb" ]; then
    fail "Missing references/fallback-adapter.md"
    return
  fi
  for tok in "Phase 1" "Phase 2" "Phase 3" "define_subagent" "enable_subagent_tools: false" "EnableSubagentTools: false" "<SUBAGENT-STOP>" "[ROLE:"; do
    grep -Fq "$tok" "$fb" && pass "Fallback adapter includes $tok" || fail "Fallback adapter missing $tok"
  done
  check_no_pro "references"
}

run_primaries() {
  echo "=== Gate: 11 Primary Subagents + Main Orchestrator ==="
  [ -s "$REPO_ROOT/agents/superpowers-multimodel.md" ] && pass "superpowers-multimodel.md exists" || fail "Missing superpowers-multimodel.md"
  for role in implementer spec-reviewer code-reviewer re-reviewer architect planner verifier codesigner designdoc-drafter skills-implementer skills-devils-advocate; do
    local f="$REPO_ROOT/agents/${role}.md"
    if [ ! -s "$f" ]; then
      fail "Missing agents/${role}.md"
      continue
    fi
    if grep -Eq '^model:' "$f"; then
      fail "agents/${role}.md sets model: in frontmatter"
    else
      pass "agents/${role}.md omits model:"
    fi
    if grep -Fq "<SUBAGENT-STOP>" "$f" && grep -Fq "[ROLE:" "$f"; then
      pass "agents/${role}.md enforces leaf envelope"
    else
      fail "agents/${role}.md missing <SUBAGENT-STOP> or [ROLE:"
    fi
  done
  check_no_pro "agents"
}

run_agents() {
  run_fallback
  run_primaries
  echo "=== Gate: 8 Hidden Flash Variants & 7-Pair Mirror Parity ==="
  local count
  count="$(ls -1 "$REPO_ROOT"/agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "$count" -eq 20 ] && pass "Exactly 20 agent files present" || fail "Expected 20 agent files, found $count"
  [ -s "$REPO_ROOT/agents/research-flash.md" ] && pass "agents/research-flash.md exists" || fail "Missing agents/research-flash.md"

  for role in implementer spec-reviewer code-reviewer re-reviewer planner verifier designdoc-drafter; do
    local p="$REPO_ROOT/agents/${role}.md"
    local m="$REPO_ROOT/agents/${role}-flash.md"
    if [ ! -s "$m" ]; then
      fail "Missing agents/${role}-flash.md"
      continue
    fi
    awk '/^tools:/{t=1;next} t&&(/^---$/||/^[a-zA-Z]/){exit} t{print}' "$p" > "$TMP_DIR/p_tools"
    awk '/^tools:/{t=1;next} t&&(/^---$/||/^[a-zA-Z]/){exit} t{print}' "$m" > "$TMP_DIR/m_tools"
    if diff -u "$TMP_DIR/p_tools" "$TMP_DIR/m_tools" >/dev/null; then
      pass "${role} tools match ${role}-flash"
    else
      fail "${role} tools drift from ${role}-flash"
    fi
    awk '/^---$/{c++;next} c>=2{print}' "$p" > "$TMP_DIR/p_body"
    awk '/^---$/{c++;next} c>=2{print}' "$m" > "$TMP_DIR/m_body"
    if diff -u "$TMP_DIR/p_body" "$TMP_DIR/m_body" >/dev/null; then
      pass "${role} body matches ${role}-flash byte-for-byte"
    else
      fail "${role} body drifts from ${role}-flash"
    fi
  done
}

run_rules() {
  echo "=== Gate: Bootstrap Router, Synced Rule & Slash Skills ==="
  local us="$REPO_ROOT/skills/using-superpowers/SKILL.md"
  local ur="$REPO_ROOT/rules/using-superpowers.md"
  for tok in "Route 0" "Route 7" "default_profile" "quota" "same" "max_concurrent_inherit" "[ROLE:" "<SUBAGENT-STOP>" "fallback-adapter.md" "/teamwork-preview" "/browser"; do
    grep -Fq "$tok" "$us" && pass "using-superpowers contains $tok" || fail "using-superpowers missing $tok"
  done
  if grep -Fq -- "-->" "$us"; then
    fail "skills/using-superpowers/SKILL.md contains forbidden --> sequence"
  else
    pass "Zero --> sequence in skills/using-superpowers/SKILL.md"
  fi
  local arrow_count
  arrow_count="$(grep -c -- '-->' "$ur" || true)"
  [ "$arrow_count" -le 2 ] && pass "rules/using-superpowers.md has header-only --> ($arrow_count)" || fail "Extra --> found in rules/using-superpowers.md ($arrow_count)"
  grep -Fq "trigger: always_on" "$ur" && pass "rules/using-superpowers.md preserves trigger: always_on" || fail "rules/using-superpowers.md missing trigger: always_on"
  [ -s "$REPO_ROOT/skills/start-superpowers/SKILL.md" ] && pass "start-superpowers exists" || fail "Missing start-superpowers/SKILL.md"
  [ -s "$REPO_ROOT/skills/start-superpowers-multimodel/SKILL.md" ] && pass "start-superpowers-multimodel exists" || fail "Missing start-superpowers-multimodel/SKILL.md"
  check_no_pro "rules"
  bash "$SCRIPT_DIR/test-rule-sync.sh" >/dev/null && pass "test-rule-sync.sh passed" || fail "test-rule-sync.sh failed"
  bash "$SCRIPT_DIR/test-skill-tool-purity.sh" >/dev/null && pass "test-skill-tool-purity.sh passed" || fail "test-skill-tool-purity.sh failed"
}

run_skills() {
  local scope="$1"
  echo "=== Gate: Multi-Model Skill Wiring ($scope) ==="
  if [ "$scope" = "sdd" ] || [ "$scope" = "all" ]; then
    local sdd="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
    local disp="$REPO_ROOT/tests/antigravity/test-subagent-dispatch.sh"
    for tok in "implementer-flash" "verifier" "Tier 3 Best-of-N" "[ROLE:" "fallback-adapter.md"; do
      grep -Fq "$tok" "$sdd" && pass "SDD contains $tok" || fail "SDD missing $tok"
    done
    check_no_pro "skills/subagent-driven-development"
    grep -Fq "implementer-flash" "$disp" && grep -Fq "verifier" "$disp" && pass "test-subagent-dispatch.sh checks flash + verifier" || fail "test-subagent-dispatch.sh missing flash/verifier checks"
  fi
  if [ "$scope" = "design-plan" ] || [ "$scope" = "all" ]; then
    local bs="$REPO_ROOT/skills/brainstorming/SKILL.md"
    local wp="$REPO_ROOT/skills/writing-plans/SKILL.md"
    for tok in "research-flash" "architect" "codesigner" "designdoc-drafter"; do
      grep -Fq "$tok" "$bs" && pass "brainstorming contains $tok" || fail "brainstorming missing $tok"
    done
    for tok in "**Tier:**" "planner" "planner-flash"; do
      grep -Fq "$tok" "$wp" && pass "writing-plans contains $tok" || fail "writing-plans missing $tok"
    done
  fi
  if [ "$scope" = "workflows" ] || [ "$scope" = "all" ]; then
    grep -Fq "implementer-flash" "$REPO_ROOT/skills/dispatching-parallel-agents/SKILL.md" && grep -Fq "verifier" "$REPO_ROOT/skills/dispatching-parallel-agents/SKILL.md" && pass "dispatching-parallel-agents wired" || fail "dispatching-parallel-agents missing flash/verifier"
    grep -Fq "code-reviewer-flash" "$REPO_ROOT/skills/requesting-code-review/SKILL.md" && pass "requesting-code-review wired" || fail "requesting-code-review missing code-reviewer-flash"
    grep -Fq "skills-implementer" "$REPO_ROOT/skills/writing-skills/SKILL.md" && grep -Fq "skills-devils-advocate" "$REPO_ROOT/skills/writing-skills/SKILL.md" && pass "writing-skills wired" || fail "writing-skills missing specialist audit pipeline"
    grep -Fq "verifier-flash" "$REPO_ROOT/skills/diagnosing-superpowers/SKILL.md" && grep -Fq "implementer-flash" "$REPO_ROOT/skills/diagnosing-superpowers/SKILL.md" && pass "diagnosing-superpowers wired to flash roles" || fail "diagnosing-superpowers missing flash role wiring"
    bash "$REPO_ROOT/tests/diagnosing-superpowers/test-skill-structure.sh" >/dev/null && pass "diagnosing-superpowers structure test passed" || fail "diagnosing-superpowers structure test failed"
    check_no_pro "skills"
  fi
  bash "$SCRIPT_DIR/test-skill-tool-purity.sh" >/dev/null && pass "test-skill-tool-purity.sh passed" || fail "test-skill-tool-purity.sh failed"
}

run_release() {
  echo "=== Gate: v7.0.0 Release Manifests & README ==="
  grep -Fq '"version": "7.0.0"' "$REPO_ROOT/plugin.json" && pass "plugin.json at 7.0.0" || fail "plugin.json not 7.0.0"
  grep -Fq '"version": "7.0.0"' "$REPO_ROOT/gemini-extension.json" && pass "gemini-extension.json at 7.0.0" || fail "gemini-extension.json not 7.0.0"
  for tok in "7.0.0" "start-superpowers" "start-superpowers-multimodel" "diagnosing-superpowers" ".superpowers/config.json"; do
    grep -Fq "$tok" "$REPO_ROOT/README.md" && pass "README documents $tok" || fail "README missing $tok"
  done
}

case "$MODE" in
  --specs) run_specs ;;
  --fallback) run_fallback ;;
  --primaries) run_primaries ;;
  --agents) run_agents ;;
  --rules) run_rules ;;
  --skills) run_skills "$SUBMODE" ;;
  --release) run_release ;;
  --all)
    run_specs
    run_agents
    run_rules
    run_skills "all"
    run_release
    ;;
  *) echo "Unknown flag: $MODE" >&2; exit 2 ;;
esac

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo "FAILED ($FAILURES checks failed)"
  exit 1
fi
echo "ALL CHECKS PASSED"
