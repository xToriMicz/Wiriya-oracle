# CLAUDE_workflows.md - Short Codes & Context Management

> **Navigation**: [Main](CLAUDE.md) | [Safety](CLAUDE_safety.md) | **Workflows** | [Subagents](CLAUDE_subagents.md) | [Lessons](CLAUDE_lessons.md) | [Templates](CLAUDE_templates.md)

---

## Short Codes (Token-Efficient)

Short codes trigger `/commands`. Details loaded only when called.

| Code | Calls | Purpose |
|------|-------|---------|
| `ccc` | `/ccc` | Create Context & Compact |
| `nnn` | `/nnn` | Next Task Planning |
| `lll` | `/lll` | List Project Status |
| `rrr` | `/rrr` | Retrospective + Lesson |
| `gogogo` | `/gogogo` | Execute Plan |

**Core Pattern**: `ccc → nnn → gogogo → rrr`

**Details**: See `.claude/commands/[code].md` (loaded on demand)

---

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/snapshot` | Quick knowledge capture |
| `/distill` | Extract patterns |
| `/recap` | Fresh start context |
| `/context-finder` | Search git/issues |
| `/trace` | Find lost projects |
| `/jump` | Signal topic change |
| `/pending` | Show pending tasks |

---

## Templates

**Single source**: [CLAUDE_templates.md](CLAUDE_templates.md)

---

## `/trace` - Find Lost Projects

**Purpose**: Track down projects that have moved, graduated, or been archived. Searches across 5 parallel agent locations to build a complete picture.

#### Three Modes

| Mode | Command | What it finds |
|------|---------|---------------|
| **Project Search** | `/trace [slug\|name]` | Specific project by name |
| **Incubation View** | `/trace incubation` | All projects in lifecycle stages |
| **Graduated View** | `/trace graduated` | Projects moved to own repos |

#### Usage Examples

```bash
# Find a specific project
/trace headline              # Find by slug or name
/trace cellar                # Even if not registered

# Special modes
/trace incubation            # Show all: graduated + incubating + ideas
/trace graduated             # Only projects that moved to own repos

# Advanced flags (v2)
/trace headline --simple     # 1-line summary per location
/trace headline --deep       # Full git archaeology
/trace headline --validate   # Check broken links + symlinks
/trace headline --timeline   # Chronological focus
/trace headline --why        # Decisions & context focus
/trace headline --related    # Find connected projects
```

#### How It Works (5 Parallel Agents)

```
┌──────────────────────────────────────────────────────────────┐
│  /trace [PROJECT] launches 5 parallel agents simultaneously  │
├──────────────────────────────────────────────────────────────┤
│  Agent 1: FILES     → Current repo files + folders           │
│  Agent 2: GIT       → Commit history + rename tracking       │
│  Agent 3: ISSUES    → GitHub issues + PRs + discussions      │
│  Agent 4: REPOS     → Other repos in ~/Code                  │
│  Agent 5: MEMORY    → Retrospectives + learnings + writings  │
└──────────────────────────────────────────────────────────────┘
                              ↓
                 Merge + Deduplicate + Score Confidence
                              ↓
                    Return comprehensive results
```

#### Search Locations

| Agent | Searches | Finds |
|-------|----------|-------|
| 1. Files | `tools/`, `projects/`, `ψ/`, `.claude/` | Active files |
| 2. Git | All commits, creates, deletes, renames | History + moves |
| 3. GitHub | Issues, PRs, discussions | Planning context |
| 4. Repos | `~/ghq/github.com/xToriMicz/*` | Graduated projects |
| 5. Memory | `ψ/memory/retrospectives/`, `learnings/` | Decisions made |

#### Output Format

```markdown
## 🔍 /trace: headline

### 📊 Quick Summary
┌─────────────────────────────────────────────────────────┐
│  Status: 🟢 ACTIVE                                       │
│  Location: ~/ghq/github.com/xToriMicz/[project]      │
│  Last Activity: 2025-12-09 by nat                        │
│  Confidence: 95% (5/5 agents agree)                      │
└─────────────────────────────────────────────────────────┘

### 📍 Locations Found
| Conf | Source | Path | Status |
|------|--------|------|--------|
| 🟢 98% | Repo | ~/Code/.../the-headline | Active |
| 🟢 95% | Git | Commit abc123 | Referenced |
| 🟡 75% | Issue | #42 | Discussed |

### 📅 Timeline
2025-12 ████████████████████ (20 commits - ACTIVE)
2025-11 ████████░░░░░░░░░░░░ (8 commits)
2025-10 ██░░░░░░░░░░░░░░░░░░ (2 commits - created)
        ↑ Born                ↑ Graduated
```

#### Incubation Mode Output

```markdown
## 🥚 /trace incubation

### 🎓 Graduated (moved to own repo)
| Project | Repo | Date |
|---------|------|------|
| headline | xToriMicz/parami | 2025-12-09 |
| claude-voice | xToriMicz/[project] | 2025-12-09 |

### 🔬 Incubating (in Oracle repos)
| Project | Location | Status |
|---------|----------|--------|
| maw-tools | tools/maw | Active |
| speckit | ψ/lab/speckit | WIP |

### 💡 Ideas (not started)
| Idea | File |
|------|------|
| voice-bridge | ideas/2025-12-09_voice-bridge.md |
| cellar | ideas/2025-12-09_cellar.md |
```

#### Key Features

| Feature | Description |
|---------|-------------|
| **Parallel Search** | 5 agents run simultaneously for speed |
| **Git History** | Finds deleted/moved projects via commits |
| **Fuzzy Match** | "headlin" finds "headline" (typo-tolerant) |
| **Confidence Score** | Shows how reliable each result is |
| **Auto-Register** | High-confidence finds auto-added to slugs |
| **Graceful Degradation** | Partial results if agent fails |

#### When to Use

| Situation | Command |
|-----------|---------|
| "Where did project X go?" | `/trace X` |
| "What projects have graduated?" | `/trace graduated` |
| "Show all project lifecycle" | `/trace incubation` |
| "Is the symlink still valid?" | `/trace X --validate` |
| "Why was this decision made?" | `/trace X --why` |

**Note**: Slug in `ψ/memory/slugs.yaml` is a hint, not restriction. /trace always searches everywhere for complete picture.

---

## GitHub Workflow

### Creating Issues
When starting a new feature or bug fix:
```bash
# 1. Update main branch
git checkout main && git pull

# 2. Create a detailed issue
gh issue create --title "feat: Descriptive title" --body "$(cat <<'EOF'
## Overview
Brief description of the feature/bug.

## Current State
What exists now.

## Proposed Solution
What should be implemented.

## Technical Details
- Components affected
- Implementation approach

## Acceptance Criteria
- [ ] Specific testable criteria
- [ ] Performance requirements
- [ ] UI/UX requirements
EOF
)"
```

### Standard Development Flow
```bash
# 1. Create a branch from the issue
git checkout -b feat/issue-number-description

# 2. Make changes
# ... implement feature ...

# 3. Test thoroughly

# 4. Commit with a descriptive message
git add -A
git commit -m "feat: Brief description

- What: Specific changes made
- Why: Motivation for the changes
- Impact: What this affects

Closes #issue-number"

# 5. Push and create a Pull Request
git push -u origin branch-name
gh pr create --title "Same as commit" --body "Fixes #issue_number"

# 6. CRITICAL: NEVER MERGE PRs YOURSELF
# DO NOT use: gh pr merge
# DO NOT use: Any merge commands
# ONLY provide the PR link to the user
# WAIT for explicit user instruction to merge
# The user will review and merge when ready
```

---

## Testing Discipline

### Manual Testing Checklist
Before pushing any changes:
-   [ ] Run the build command successfully.
-   [ ] Verify there are no new build warnings or type errors.
-   [ ] Test all affected pages and features.
-   [ ] Check the browser console for errors.
-   [ ] Test for mobile responsiveness if applicable.
-   [ ] Verify all interactive features work as expected.

---

## Tracks System (Multi-Track Context)

### Location
- `ψ/inbox/tracks/INDEX.md` - Track overview with heat status
- `ψ/inbox/tracks/YYMMDDHHMM-title.md` - Individual track files

### Track Heat Status

| Symbol | Status | Age | Meaning |
|--------|--------|-----|---------|
| Hot | Now | <1h | Active work |
| Warm | Recent | <24h | Easy pickup |
| Cooling | Needs attention | 1-7d | Review or jump |
| Cold | Forgotten | >7d | Decide: resume or archive |
| Dormant | Archive candidate | >30d | Archive with /jump archive |

### Track File Format

```markdown
# Track: [Title]

**Created**: YYYY-MM-DD HH:MM
**Last touched**: YYYY-MM-DD HH:MM
**Status**: [heat status]

---

## Goal
[What this track is about]

## Current State
[Where things are now]

## Next Action
- [ ] Specific next step

## Context
[Files, commands, links]
```

### Integration with /jump

When using `/jump [topic]`:
1. Current track updated with last touched time
2. New track created or resumed
3. INDEX.md auto-updated

### Archive Pattern

- **Dormant tracks**: Move to `ψ/inbox/tracks/archive/`
- **Git history**: Tracks are tracked, nothing lost

**Oracle principle**: Nothing is deleted - git history is infinite undo.

---

**See also**: [CLAUDE_templates.md](CLAUDE_templates.md) for retrospective template, [CLAUDE_safety.md](CLAUDE_safety.md) for PR workflow rules

---

## Context Management - ไม่ต้องกลัว\!

| Level | Action |
|-------|--------|
| 70%+ | ⚡ Finish soon |
| 80%+ | ⚠️ Wrap up |
| 90%+ | 🚨 Manual handoff |
| **95%+** | 🚨 AUTO-HANDOFF (creates file) |

**อย่ากลัว context หมด:**
- Auto-compact enabled
- Auto-handoff at 95%
- อัปเดต handoff เรื่อยๆ
- ข้อมูลไม่หลุด

