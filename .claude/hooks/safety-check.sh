#!/bin/bash
# Jingjing Safety Check — blocks dangerous commands
# Principle 1: Nothing is Deleted

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# === DANGEROUS PATTERNS ===

# Block rm -rf
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*rm\s+-rf\s'; then
  echo "BLOCKED: rm -rf not allowed (Nothing is Deleted)." >&2
  echo "Use: mv <path> /tmp/trash_\$(date +%Y%m%d_%H%M%S)_\$(basename <path>)" >&2
  exit 2
fi

# Block force flags (git/npm/yarn/pnpm only)
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*(git|npm|yarn|pnpm)\s+[a-z-]+\s+.*(\s-f(\s|$)|--force(\s|$))'; then
  echo "BLOCKED: Force flags not allowed (Nothing is Deleted)." >&2
  exit 2
fi

# Block reset --hard
if echo "$CMD" | grep -qE '(^|;|&&|\|\|)\s*git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard not allowed." >&2
  exit 2
fi

# Block git push --force
if echo "$CMD" | grep -qE 'git\s+push\s+.*--force'; then
  echo "BLOCKED: git push --force not allowed (Nothing is Deleted)." >&2
  exit 2
fi

exit 0
