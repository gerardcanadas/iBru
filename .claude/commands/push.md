Commit all modified/untracked Swift files and push to main.

Steps:
1. Run `git status` and `git diff` to see what changed
2. Run the test suite and confirm all tests pass before committing:
   ```
   xcodebuild test \
     -project iBru.xcodeproj \
     -scheme iBru \
     -sdk iphonesimulator \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "passed|failed|error:"
   ```
   If any test fails, stop and fix it before proceeding.
3. Run `git log -5 --oneline` to match the commit message style of recent commits
4. Stage only relevant source files (never `.env`, never `xcuserdata/`, never unrelated files)
5. Write a concise commit message: one subject line starting with a conventional prefix (`feat:`, `fix:`, `refactor:`) that describes WHY, not what
6. Commit with Co-Authored-By trailer:
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
