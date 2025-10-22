# Codex Guidelines

This repository hosts a personal catalog of reusable automation scripts. The notes below capture conventions to keep the codebase tidy and discoverable when collaborating with Codex or other tooling.

## Repository Structure
- Each top-level directory represents a category (for example, `network/`).
- Scripts live directly under their category directory and should include an executable shebang when applicable.
- Shared tooling belongs in `tools/`. The README generator lives here.

## Adding Scripts
- Create or choose an existing category directory before adding a script.
- Place a concise summary in the first non-empty comment at the top of the file. The README generator extracts this line automatically.
- Include a "Supports: ..." comment line (for example, `Supports: Linux, OpenWrt`) to enumerate compatible operating systems. Linux is assumed when omitted.
- Ensure every script is idempotent: running it multiple times must not produce duplicate state or errors.
- Prefer descriptive filenames and keep implementations in English.
- Expose script parameters with sensible defaults so the script can run unattended; document overrides in `usage` output or comments.

## Automation Workflow
- Run `python tools/update_readme.py` after adding or updating scripts to refresh the documentation and remote execution commands.
- Use `python tools/update_readme.py --check` during reviews to confirm the README is up to date.
- The generator excludes hidden directories and the `tools/` folder from script listings by default.

## Remote Execution Notes
- Remote commands use `curl -sSL <url> | <interpreter>` and automatically pick `sh`, `bash`, or other runtimes based on each script's shebang. Adjust manually if a different invocation is required.
- Verify external download URLs before committing changes to avoid supply-chain risks.
- When documenting GitHub downloads, provide the plain command first and note that users can opt into `${GH_PROXY:-}` prefixes (for example, suggest `export GH_PROXY=https://gh.monlor.com/` before running accelerated downloads).
- Provide flags or environment variables for user-specific configuration where feasible.

## Quality Checklist
- [ ] Script passes a basic syntax check (for example, `sh -n` or language equivalent).
- [ ] Script handles network or dependency failures gracefully and emits actionable errors.
- [ ] Script tidies temporary files and restores state on early exit.
- [ ] README regenerated and reviewed for accurate descriptions.
- [ ] Comments and user-facing strings are written in English.
