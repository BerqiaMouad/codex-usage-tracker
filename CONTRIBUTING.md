# Contributing

Thanks for contributing.

## Ground rules

- Keep PRs focused and reasonably small.
- Do not commit build products, screenshots, local Codex data, or release archives.
- Avoid machine-specific paths and personal/work email addresses in the repo.

## Local checks

Before opening a PR, run:

```bash
swift build
swift run CodexUsageTracker --self-check
```

If you touched packaging or app launch behavior, also run:

```bash
./script/build_and_run.sh --verify
```

## PR expectations

- Explain the user-facing change clearly.
- Mention any tradeoffs or known limitations.
- Include screenshots only when the UI changed materially.
