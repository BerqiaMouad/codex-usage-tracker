# Codex Usage Tracker

Codex Usage Tracker is a native macOS app that reads local Codex session data from `~/.codex` and shows:

- all-time, monthly, and daily authenticated OpenAI usage
- date filter presets for all time, this month, last month, and today
- model-by-model token breakdowns
- recent tracked threads
- estimated API-style cost using editable per-model rates

It intentionally excludes MiniMax usage from the totals.

## Requirements

- macOS 14 or newer
- Codex installed and used locally on the same Mac
- Swift 6.3+ if you want to build from source

## Run locally

```bash
./script/build_and_run.sh
```

## Verify locally

```bash
swift run CodexUsageTracker --self-check
```

## Build release artifacts

```bash
./script/package_release.sh zip
./script/package_release.sh dmg
./script/package_release.sh both
```

Artifacts are written to `dist/release/`.

## Install for end users

Unsigned builds can work, but macOS Gatekeeper may warn on first launch.

1. Open the `.dmg`
2. Drag `CodexUsageTracker.app` to `Applications`
3. Right-click the app in `Applications` and choose `Open`
4. If needed, allow it in `System Settings -> Privacy & Security`

If a downloaded build is quarantined, users can remove the quarantine attribute:

```bash
xattr -dr com.apple.quarantine /Applications/CodexUsageTracker.app
```

## Notes

- Cost is an estimate, not Codex billing truth
- Default pricing is based on the public OpenAI API pricing page
- Tool-call fees, discounts, taxes, and internal billing differences are not included
