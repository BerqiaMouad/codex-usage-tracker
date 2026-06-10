# Agent Notes

## Project shape

- This is a SwiftPM macOS app.
- App source lives in `Sources/CodexUsageTracker/`.
- Local run/build scripts live in `script/`.
- Release artifacts go to `dist/release/` and should not be committed.

## Product intent

- Keep the app native and simple.
- The tracker reads local Codex usage from `~/.codex`.
- Authenticated OpenAI usage is the source of truth for totals.
- MiniMax usage should stay excluded unless the product direction changes explicitly.

## Safety and privacy

- Never commit local Codex databases, rollout files, screenshots, or generated archives.
- Never introduce personal or work email addresses into committed files unless the user explicitly asks.
- Avoid hardcoding machine-specific absolute paths.

## Change guidelines

- Prefer small, testable changes.
- Keep startup work cheap; large local histories are common.
- Preserve the self-check path: `swift run CodexUsageTracker --self-check`.
- If packaging changes, keep unsigned builds working and make signing/notarization optional.

## Before finishing

- Run `swift build`.
- Run `swift run CodexUsageTracker --self-check`.
- If you changed packaging or launch behavior, verify with `./script/build_and_run.sh --verify`.
