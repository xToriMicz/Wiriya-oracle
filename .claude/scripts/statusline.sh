#!/bin/bash
# Jingjing Statusline — built-in statusLine (reads JSON from stdin)
# Output: 📊 Opus 4.6 56% | 🕐 08:24 | 10 Mar 2026 | Jingjing-oracle

ROOT="${CLAUDE_PROJECT_DIR:-/Users/angkana/Jingjing-oracle}"
CACHE="$ROOT/ψ/active/statusline.json"

# Read JSON from stdin (Claude Code provides this)
INPUT=$(cat)

# Save to cache for token-check.sh and other hooks
if [ -n "$INPUT" ]; then
  mkdir -p "$(dirname "$CACHE")"
  echo "$INPUT" > "$CACHE"
fi

# Time + Date + Project
TIME=$(date '+%H:%M')
DATE=$(date '+%d %b %Y')
PROJECT=$(basename "$CLAUDE_PROJECT_DIR")

# Context from stdin JSON
CONTEXT=""
if [ -n "$INPUT" ]; then
  model=$(echo "$INPUT" | jq -r '.model.display_name // empty' 2>/dev/null)
  pct=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)

  if [ -n "$pct" ] && [ "$pct" != "null" ]; then
    pct=${pct%%.*}  # truncate decimals
    if [ "$pct" -ge 97 ] 2>/dev/null; then
      CONTEXT="🚨 ${model} ${pct}%"
    elif [ "$pct" -ge 95 ] 2>/dev/null; then
      CONTEXT="⚠️ ${model} ${pct}%"
    elif [ "$pct" -ge 80 ] 2>/dev/null; then
      CONTEXT="⚡ ${model} ${pct}%"
    else
      CONTEXT="📊 ${model} ${pct}%"
    fi
  fi
fi

# Output
if [ -n "$CONTEXT" ]; then
  echo "${CONTEXT} | 🕐 ${TIME} | ${DATE} | ${PROJECT}"
else
  echo "🕐 ${TIME} | ${DATE} | ${PROJECT}"
fi
