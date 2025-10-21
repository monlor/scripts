# monlor/scripts

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE) ![Scripts 1](https://img.shields.io/badge/scripts-1-blue.svg) ![Categories 1](https://img.shields.io/badge/categories-1-lightgrey.svg)

Collection of personal automation scripts organized by category for quick discovery and remote execution.

## Category Navigation
- [network (1)](#network)

## network
| Script | Summary | Supported OS | Remote Execution |
| --- | --- | --- | --- |
| [`china-ipset-update.sh`](https://github.com/monlor/scripts/blob/main/network/china-ipset-update.sh) | Update ipset entries for China mainland IPv4/IPv6 ranges. Safe to rerun. | Linux, OpenWrt | `curl -sSL https://raw.githubusercontent.com/monlor/scripts/main/network/china-ipset-update.sh | sh` |


## Maintenance

- Each category maps to a subdirectory in the repository root.
- Script descriptions are automatically pulled from the first non-empty comment at the top of each file.
- Add a comment line such as "Supports: Linux, OpenWrt" to enumerate compatible operating systems (defaults to Linux when omitted).
- Export script parameters with safe defaults so commands can run non-interactively; document overrides in the script usage output when applicable.
- Remote execution commands automatically select interpreters based on each script's shebang; adjust manually if special tooling is required.
- Regenerate this document with `python tools/update_readme.py`; avoid manual edits to the generated sections.

## Contribution

- Clone the repository: `git clone https://github.com/monlor/scripts.git`
- Regenerate the index after adding scripts: `python tools/update_readme.py`
- Remote execution example: `curl -sSL https://raw.githubusercontent.com/monlor/scripts/main/path/to/script.sh | sh`
- Describe your script by placing a concise comment on the first non-empty line (for example, `# Sync router IP list`).
- Declare supported systems with a comment such as `# Supports: Linux, OpenWrt`; omit to default to Linux only.
