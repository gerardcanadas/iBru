Run a real Xcode build and report any actual compiler errors.

Execute:
```
xcodebuild -scheme iBru -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|warning:|BUILD"
```

IMPORTANT: SourceKit (the IDE indexer) produces false "Cannot find type X in scope" errors for types that clearly exist in the project — Baby, MedicationPlan, FrequencyUnit, NotificationManager, etc. These are indexing noise, NOT real errors. Only treat output from `xcodebuild` as ground truth.

If the build succeeds, say so briefly. If it fails, show only the real compiler errors (lines containing `error:`) and fix them.
