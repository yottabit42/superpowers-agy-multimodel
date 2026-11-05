#!/usr/bin/env bash
# Static lint for bundled agent definitions (agents/*.md).
# The platform hangs a subagent whose tools: list contains an unknown name,
# so this gate fails the build on any tool name outside the documented set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENTS_DIR="$REPO_ROOT/agents"
FAILURES=0

KNOWN_TOOLS="view_file write_to_file replace_file_content multi_replace_file_content list_dir find_by_name grep_search search_web read_url_content run_command manage_task schedule list_permissions ask_permission invoke_subagent define_subagent send_message manage_subagents ask_question generate_image"

fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "  [PASS] $1"; }

[ -d "$AGENTS_DIR" ] || { echo "[FAIL] agents/ directory missing"; exit 1; }

for agent_file in "$AGENTS_DIR"/*.md; do
  base_name="$(basename "$agent_file")"
  name="$(sed -n 's/^name:[[:space:]]*//p' "$agent_file" | head -1 | tr -d '\r')"
  desc="$(sed -n 's/^description:[[:space:]]*//p' "$agent_file" | head -1 | tr -d '\r')"
  [ -n "$name" ] && pass "$base_name: name present" || fail "$base_name: missing name"
  [ -n "$desc" ] && pass "$base_name: description present" || fail "$base_name: missing description"
  [ "$name.md" = "$base_name" ] && pass "$base_name: name matches filename" || fail "$base_name: name '$name' != filename"

  model="$(sed -n 's/^model:[[:space:]]*//p' "$agent_file" | head -1 | tr -d '\r')"
  hidden="$(sed -n 's/^hidden:[[:space:]]*//p' "$agent_file" | head -1 | tr -d '\r')"
  subagent="$(sed -n 's/^subagent:[[:space:]]*//p' "$agent_file" | head -1 | tr -d '\r')"
  main_agent="$(sed -n 's/^mainAgent:[[:space:]]*//p' "$agent_file" | head -1 | tr -d '\r')"

  if [ "$model" = "pro" ]; then
    echo "  [FAIL] $base_name: model: pro is banned"
    FAILURES=$((FAILURES + 1))
  fi

  case "$base_name" in
    superpowers-multimodel.md)
      if [ -n "$model" ] || [ "$main_agent" != "true" ] || [ "$subagent" != "false" ] || grep -Eq '^tools:' "$agent_file"; then
        echo "  [FAIL] $base_name: must set mainAgent: true, subagent: false, and omit both model: and tools:"
        FAILURES=$((FAILURES + 1))
      else
        echo "  [PASS] $base_name: valid mainAgent schema"
      fi
      ;;
    *-flash.md)
      if [ "$model" != "flash" ] || [ "$hidden" != "true" ] || [ "$subagent" != "true" ] || [ "$main_agent" != "false" ]; then
        echo "  [FAIL] $base_name: *-flash.md must set model: flash, hidden: true, subagent: true, mainAgent: false"
        FAILURES=$((FAILURES + 1))
      else
        echo "  [PASS] $base_name: valid hidden flash subagent schema"
      fi
      ;;
    *)
      if [ -n "$model" ] || [ "$hidden" = "true" ] || [ "$subagent" != "true" ] || [ "$main_agent" != "false" ]; then
        echo "  [FAIL] $base_name: primary subagent must omit model:, omit hidden: true, and set subagent: true, mainAgent: false"
        FAILURES=$((FAILURES + 1))
      else
        echo "  [PASS] $base_name: valid primary subagent schema (model omitted)"
      fi
      ;;
  esac

  if [ "$subagent" = "true" ]; then
    if ! grep -Eq '^tools:' "$agent_file"; then
      echo "  [FAIL] $base_name: leaf subagent must declare explicit tools: allowlist"
      FAILURES=$((FAILURES + 1))
    fi
    for forbidden_tool in invoke_subagent define_subagent manage_subagents; do
      if awk '/^tools:/{t=1;next} t&&(/^---$/||/^[a-zA-Z]/){exit} t{print}' "$agent_file" | grep -Eq "(^|[^a-z_])${forbidden_tool}([^a-z_]|$)"; then
        echo "  [FAIL] $base_name: leaf subagent must not declare $forbidden_tool"
        FAILURES=$((FAILURES + 1))
      fi
    done
  fi

  # tools entries: lines beginning "  - " between "tools:" and the next top-level key
  tools="$(awk '/^tools:/{t=1;next} t&&(/^[a-zA-Z]/||/^---$/){exit} t&&/^[[:space:]]*- /{print $2}' "$agent_file")"
  for tool in $tools; do
    case " $KNOWN_TOOLS " in
      *" $tool "*) pass "$base_name: tool '$tool' known";;
      *) fail "$base_name: tool '$tool' NOT in documented tool set";;
    esac
  done
done

echo ""
if [ "$FAILURES" -eq 0 ]; then echo "[PASS] Agent frontmatter lint passed"; else echo "[FAIL] $FAILURES failure(s)"; exit 1; fi
