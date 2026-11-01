"""Fail before deployment if the web bundle lacks the Functions plugin."""
from pathlib import Path


def verify(bundle: str) -> None:
    if "flutter-fire-fn" not in bundle:
        raise ValueError("Cloud Functions web plugin is missing. Rebuild with a fresh .dart_tool/flutter_build cache before deploying.")


if __name__ == "__main__":
    verify(Path("build/web/main.dart.js").read_text(encoding="utf-8"))
    print("Cloud Functions web plugin is present in the release bundle.")
