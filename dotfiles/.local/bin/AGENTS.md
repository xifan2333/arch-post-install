# Repository Guidelines

## Project Structure & Module Organization
The repository root hosts three Bash executables: `ccm` for Claude providers, `cxm` for Codex, and `gnm` for Gemini. Each script is self-contained, documented inline, and writes user state under XDG paths such as `~/.config/claude`, `~/.config/codex`, `~/.config/gemini`, and `~/.codex`. Product docs live in `README.md` (简体中文) and `README_en.md`; update both when behavior changes. Avoid committing generated config or credential files—those belong in the user home directories the tools create on demand.

## Build, Test, and Development Commands
- `./ccm help`, `./cxm help`, `./gnm help` show live command references; run them after edits to confirm usage text stays accurate.
- `shellcheck ccm cxm gnm` surfaces common Bash pitfalls; run before opening a review.
- `./ccm ls`, `./cxm ls`, and `./gnm ls` exercise provider listing without touching secrets, making them safe smoke tests.

## Coding Style & Naming Conventions
Scripts target Bash 5 with `set -e` enabled. Use four-space indentation, snake_case for functions, and descriptive helper names (`get_current_config`, `generate_config`). Prefer here-docs for template files and keep user-facing strings localized directly in the script. When adding flags or commands, mirror the existing `case` layout and extend help text in the same section.

## Testing Guidelines
There is no dedicated automated test suite yet, so combine `shellcheck` with manual command runs. Add throwaway providers in your `$HOME` sandbox (never real keys) and verify `init`, `add`, `use`, and `rm` flows for each manager. When editing file-writing logic, manually inspect the generated files under `~/.config/*` and `~/.codex` to ensure formats remain unchanged.

## Commit & Pull Request Guidelines
Follow the existing convention of concise, scope-leading messages (e.g., `v1.0.0: completed`). Group related script updates together and describe user-visible behavior shifts first. Pull requests should include: summary of changes, test evidence (`shellcheck` output or command transcripts), affected scripts, and any migration notes for existing configs. Reference issues when applicable and call out security-sensitive edits explicitly.

## Security & Configuration Tips
Treat API keys as secrets—never echo them in logs or commit them. New contributors should verify that added logs redact `${api_key}` variables and that generated files remain `0600`. Encourage users to rotate credentials after testing and document any required environment variables in both READMEs.
