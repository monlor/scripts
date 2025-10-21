"""Generate README index for categorized scripts."""

from __future__ import annotations

import argparse
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple


REPO_SLUG = "monlor/scripts"
RAW_BASE_URL = f"https://raw.githubusercontent.com/{REPO_SLUG}/main"

REPO_ROOT = Path(__file__).resolve().parents[1]
README_PATH = REPO_ROOT / "README.md"

IGNORED_DIRS = {".git", "tools", ".github", "__pycache__"}
SUPPORTED_SUFFIXES = {".sh", ".bash", ".py", ".rb", ".js", ".ts", ".ps1"}
DEFAULT_OS = ["Linux"]
OS_ALIASES = {
    "linux": "Linux",
    "gnu/linux": "Linux",
    "openwrt": "OpenWrt",
    "open-wrt": "OpenWrt",
    "lede": "OpenWrt",
    "mac": "macOS",
    "macos": "macOS",
    "osx": "macOS",
    "darwin": "macOS",
    "windows": "Windows",
    "win": "Windows",
}


@dataclass
class ScriptInfo:
    name: str
    path: Path
    description: str
    executor: str
    supported_os: List[str]

    @property
    def relative_path(self) -> Path:
        return self.path.relative_to(REPO_ROOT)

    @property
    def github_url(self) -> str:
        return f"https://github.com/{REPO_SLUG}/blob/main/{self.relative_path.as_posix()}"

    @property
    def remote_command(self) -> str:
        script_path = self.relative_path.as_posix()
        return f"curl -sSL {RAW_BASE_URL}/{script_path} | {self.executor}"


@dataclass
class Category:
    name: str
    path: Path
    scripts: List[ScriptInfo]

    @property
    def anchor(self) -> str:
        return self.name.lower().replace(" ", "-")


def iter_category_dirs() -> Iterable[Path]:
    for entry in sorted(REPO_ROOT.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name in IGNORED_DIRS:
            continue
        if entry.name.startswith(".") or entry.name.startswith("_"):
            continue
        yield entry


def detect_executor(script_path: Path) -> str:
    interpreter = ""
    try:
        with script_path.open("r", encoding="utf-8") as handle:
            first_line = handle.readline().strip()
    except UnicodeDecodeError:
        first_line = ""

    if first_line.startswith("#!"):
        shebang = first_line[2:].strip()
        parts = shebang.split()
        if parts:
            if parts[0].endswith("env") and len(parts) > 1:
                interpreter = parts[1]
            else:
                interpreter = parts[0]

    interpreter = interpreter.lower()

    mapping = {
        "bash": "bash",
        "sh": "sh",
        "python3": "python3",
        "python": "python",
        "node": "node",
        "ruby": "ruby",
        "perl": "perl",
        "pwsh": "pwsh",
        "powershell": "powershell",
    }

    if interpreter:
        for key, value in mapping.items():
            if key in interpreter:
                return value

    suffix = script_path.suffix.lower()
    if suffix in {".bash"}:
        return "bash"
    if suffix in {".sh"}:
        return "sh"
    if suffix in {".py"}:
        return "python3"
    if suffix in {".rb"}:
        return "ruby"
    if suffix in {".js", ".ts"}:
        return "node"
    if suffix in {".ps1"}:
        return "pwsh"

    return "sh"


def iter_scripts(category_dir: Path) -> Iterable[ScriptInfo]:
    for entry in sorted(category_dir.iterdir()):
        if entry.is_dir():
            continue
        if entry.suffix and entry.suffix not in SUPPORTED_SUFFIXES:
            continue
        description, supported_os = extract_script_metadata(entry)
        executor = detect_executor(entry)
        yield ScriptInfo(
            name=entry.name,
            path=entry,
            description=description,
            executor=executor,
            supported_os=supported_os,
        )


def _dedupe_preserve_order(items: Iterable[str]) -> List[str]:
    seen = set()
    result: List[str] = []
    for item in items:
        if not item:
            continue
        if item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result


def _normalize_os_label(label: str) -> str:
    cleaned = label.strip()
    if not cleaned:
        return ""
    key = cleaned.lower()
    return OS_ALIASES.get(key, cleaned)


def extract_script_metadata(path: Path) -> Tuple[str, List[str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        return "Unable to decode file for description", DEFAULT_OS.copy()

    description: str = ""
    os_candidates: List[str] = []
    in_docstring = False
    docstring_delimiter = ""

    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue

        if line.startswith("#!"):
            continue

        if in_docstring:
            if line.endswith(docstring_delimiter):
                content = line[: -len(docstring_delimiter)].strip()
                if content and not description:
                    description = content
                in_docstring = False
                continue
            if not description and line:
                description = line
            continue

        is_comment = False
        comment_text = ""
        if line.startswith("#"):
            comment_text = line.lstrip("#").strip()
            is_comment = True
        elif line.startswith("//"):
            comment_text = line.lstrip("/").strip()
            is_comment = True

        if is_comment:
            lower_comment = comment_text.lower()
            matched_os = False
            for prefix in ("supports:", "supported os:", "os:", "platform:", "platforms:"):
                if lower_comment.startswith(prefix):
                    os_string = comment_text[len(prefix):].strip()
                    for part in os_string.split(","):
                        normalized = _normalize_os_label(part)
                        if normalized:
                            os_candidates.append(normalized)
                    matched_os = True
                    break
            if not matched_os and comment_text and not description:
                description = comment_text
            continue

        if line.startswith("\"\"\"") or line.startswith("'''"):
            docstring_delimiter = line[:3]
            remainder = line[3:].strip()
            if remainder.endswith(docstring_delimiter) and len(remainder) > 3:
                content = remainder[: -len(docstring_delimiter)].strip()
                if content and not description:
                    description = content
                break
            if remainder and not description:
                description = remainder
            if line.count(docstring_delimiter) >= 2:
                break
            in_docstring = True
            continue

        break

    if not description:
        description = "No description available"

    supported_os = _dedupe_preserve_order(os_candidates)
    if not supported_os:
        supported_os = DEFAULT_OS.copy()

    return description, supported_os


def build_categories() -> List[Category]:
    categories: List[Category] = []
    for directory in iter_category_dirs():
        scripts = list(iter_scripts(directory))
        categories.append(Category(name=directory.name, path=directory, scripts=scripts))
    return categories


def render_badges(categories: Iterable[Category]) -> str:
    categories_list = list(categories)
    total_categories = len(categories_list)
    total_scripts = sum(len(category.scripts) for category in categories_list)

    license_badge = "[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)"
    scripts_badge = (
        f"![Scripts {total_scripts}](https://img.shields.io/badge/scripts-{total_scripts}-blue.svg)"
    )
    categories_badge = (
        f"![Categories {total_categories}](https://img.shields.io/badge/categories-{total_categories}-lightgrey.svg)"
    )

    return " ".join([license_badge, scripts_badge, categories_badge])


def render_toc(categories: Iterable[Category]) -> str:
    items = []
    for category in categories:
        count = len(category.scripts)
        display_name = category.name
        items.append(f"- [{display_name} ({count})](#{category.anchor})")
    if not items:
        return "- No categories detected yet. Add subdirectories and regenerate the README."
    return "\n".join(items)


def render_category_section(category: Category) -> str:
    heading = f"## {category.name}\n"
    if not category.scripts:
        return heading + "> No scripts in this category yet. Add files and regenerate the README.\n"

    table_header = "| Script | Summary | Supported OS | Remote Execution |\n| --- | --- | --- | --- |"
    rows = []
    for script in category.scripts:
        script_link = f"[`{script.name}`]({script.github_url})"
        description = script.description.replace("|", "\\|")
        os_display = ", ".join(script.supported_os)
        curl_cmd = f"`{script.remote_command}`"
        rows.append(f"| {script_link} | {description} | {os_display} | {curl_cmd} |")

    return heading + "\n".join([table_header, *rows]) + "\n"


def build_readme(categories: List[Category]) -> str:
    badges = render_badges(categories)
    toc = render_toc(categories)
    sections = "\n".join(render_category_section(category) for category in categories)
    if not sections:
        sections = (
            "## Category Index\n> No script categories detected yet. Create subdirectories and rerun the generator to populate this section.\n"
        )

    content = f"""# monlor/scripts

{badges}

Collection of personal automation scripts organized by category for quick discovery and remote execution.

## Category Navigation
{toc}

{sections}

## Maintenance

- Each category maps to a subdirectory in the repository root.
- Script descriptions are automatically pulled from the first non-empty comment at the top of each file.
- Add a comment line such as "Supports: Linux, OpenWrt" to enumerate compatible operating systems (defaults to Linux when omitted).
- Export script parameters with safe defaults so commands can run non-interactively; document overrides in the script usage output when applicable.
- Remote execution commands automatically select interpreters based on each script's shebang; adjust manually if special tooling is required.
- Regenerate this document with `python tools/update_readme.py`; avoid manual edits to the generated sections.

## Contribution

- Clone the repository: `git clone https://github.com/{REPO_SLUG}.git`
- Regenerate the index after adding scripts: `python tools/update_readme.py`
- Remote execution example: `curl -sSL {RAW_BASE_URL}/path/to/script.sh | sh`
- Describe your script by placing a concise comment on the first non-empty line (for example, `# Sync router IP list`).
- Declare supported systems with a comment such as `# Supports: Linux, OpenWrt`; omit to default to Linux only.
"""
    return textwrap.dedent(content).strip() + "\n"


def write_readme(content: str) -> None:
    README_PATH.write_text(content, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate README index for scripts")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check whether README is up to date without writing",
    )
    args = parser.parse_args()

    categories = build_categories()
    content = build_readme(categories)

    if args.check:
        current = README_PATH.read_text(encoding="utf-8") if README_PATH.exists() else ""
        if current == content:
            print("README is up to date.")
        else:
            print("README needs regeneration. Run without --check to update it.")
        return

    write_readme(content)
    print("README generated.")


if __name__ == "__main__":
    main()
