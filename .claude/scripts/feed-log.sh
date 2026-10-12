#!/bin/bash
# Feed logger — writes Oracle activity to ~/.oracle/feed.log
# Format: TIMESTAMP | ORACLE | HOST | EVENT | PROJECT | SESSION_ID » MESSAGE

FEED_LOG="$HOME/.oracle/feed.log"
mkdir -p "$(dirname "$FEED_LOG")"

# Read JSON from stdin
INPUT=$(cat 2>/dev/null || echo "{}")

# Parse JSON fields
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "unknown"' 2>/dev/null || echo "unknown")
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Extract oracle name from project dir
ORACLE_NAME=$(basename "${CLAUDE_PROJECT_DIR:-unknown}" | sed 's/-oracle$//' | sed 's/\.wt-.*//')

HOST=$(hostname -s 2>/dev/null || echo "local")
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
PROJECT=$(basename "${CLAUDE_PROJECT_DIR:-unknown}")

# Build message based on event type
case "$EVENT" in
  PreToolUse|PostToolUse|PostToolUseFailure)
    MSG="$TOOL_NAME"
    ;;
  UserPromptSubmit)
    MSG=$(echo "$PROMPT" | head -1 | cut -c1-200)
    ;;
  *)
    MSG="$EVENT"
    ;;
esac
MSG="${MSG:-(no message)}"

echo "$TIMESTAMP | $ORACLE_NAME | $HOST | $EVENT | $PROJECT | $SESSION_ID » $MSG" >> "$FEED_LOG"
