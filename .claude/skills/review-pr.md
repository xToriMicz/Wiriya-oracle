# /review-pr — Cross-repo PR Review

> ดู PR diff จาก repo อื่นโดยไม่ต้อง clone

## Usage

```
/review-pr facebook-toolkit 15     # ดู PR #15 ใน xToriMicz/facebook-toolkit
/review-pr ge-db-thai 8            # ดู PR #8 ใน xToriMicz/ge-db-thai
/review-pr owner/repo 123          # ดู PR #123 ใน repo ใดก็ได้
```

## Steps

1. Parse arguments: `{repo} {pr-number}`
   - If repo has no `/`, prepend `xToriMicz/`
2. Fetch PR info:
   ```bash
   gh pr view {pr-number} --repo {repo} --json title,body,state,author,files,additions,deletions
   ```
3. Fetch diff:
   ```bash
   gh pr diff {pr-number} --repo {repo}
   ```
4. Review the diff — check for:
   - Security issues (token leaks, missing auth, SQL injection, XSS)
   - User data isolation (WHERE user_fb_id)
   - Logic bugs
   - Missing error handling
5. Output review summary with line references

## Output Format

```
## PR #{number}: {title}
**Author**: {author} | **Files**: {count} | +{additions} -{deletions}

### Review
- ✅ / ⚠️ / ❌ {finding}

### Summary
{one-line verdict}
```
