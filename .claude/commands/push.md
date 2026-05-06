Commit all modified/untracked Swift files and push to main.

Steps:
1. Run `git status` and `git diff` to see what changed
2. Run `git log -5 --oneline` to match the commit message style of recent commits
3. Stage only relevant source files (never `.env`, never `xcuserdata/`, never unrelated files)
4. Write a concise commit message: one subject line starting with a conventional prefix (`feat:`, `fix:`, `refactor:`) that describes WHY, not what
5. Commit with Co-Authored-By trailer:
   ```
   Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
   ```
6. Push: `git push origin main`
7. Confirm with the resulting commit SHA

Do NOT:
- Stage `.claude/` directory contents
- Stage `xcuserdata/`
- Force-push
- Amend existing commits
- Skip hooks with `--no-verify`

If the push is rejected (remote has diverged), pull with `--no-rebase --no-edit` first, then push.
