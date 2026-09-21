#!/usr/bin/env python3
"""Validate copy limits in the localized App Store Markdown files."""

from pathlib import Path
import re


ROOT = Path(__file__).parent
FILES = [ROOT / "metadata.zh-Hans.md", ROOT / "metadata.en-US.md"]
LIMITS = {
    "app_name": (30, "characters"),
    "subtitle": (30, "characters"),
    "promotional_text": (170, "characters"),
    "description": (4000, "characters"),
    "keywords": (100, "bytes"),
    "version_notes": (4000, "characters"),
}
FORBIDDEN_KEYWORDS = {
    "flow",
    "flow.app",
    "forest",
    "be focused",
    "focus to-do",
}
FIELD_PATTERN = re.compile(
    r"<!-- field:(?P<locale>[^.]+)\.(?P<name>[a-z_]+) -->\s*"
    r"```text\n(?P<value>.*?)\n```",
    re.DOTALL,
)


def main() -> None:
    seen: dict[str, dict[str, str]] = {}
    failures: list[str] = []

    for path in FILES:
        text = path.read_text(encoding="utf-8")
        for match in FIELD_PATTERN.finditer(text):
            locale = match["locale"]
            seen.setdefault(locale, {})[match["name"]] = match["value"]

    for locale in ("zh-Hans", "en-US"):
        fields = seen.get(locale, {})
        for name, (limit, unit) in LIMITS.items():
            value = fields.get(name)
            if value is None:
                failures.append(f"{locale}.{name}: missing")
                continue
            actual = len(value.encode("utf-8")) if unit == "bytes" else len(value)
            print(f"{locale}.{name}: {actual}/{limit} {unit}")
            if actual > limit:
                failures.append(f"{locale}.{name}: {actual} > {limit} {unit}")

        keywords = [item.strip().lower() for item in fields.get("keywords", "").split(",")]
        competitors = sorted(set(keywords) & FORBIDDEN_KEYWORDS)
        if competitors:
            failures.append(f"{locale}.keywords: competitor terms {competitors}")

    if failures:
        raise SystemExit("\n".join(["metadata validation failed:", *failures]))

    print("metadata validation passed")


if __name__ == "__main__":
    main()
