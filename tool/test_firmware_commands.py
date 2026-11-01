"""Run the actual firmware JSON visitor against ArduinoJson on a host C++ compiler."""
import argparse
from pathlib import Path
import shutil
import subprocess

args = argparse.ArgumentParser()
args.add_argument("--include", required=True, help="ArduinoJson src directory")
args.add_argument("--extract-only", action="store_true")
options = args.parse_args()
source = Path("firmware/ubsoft_turnstile/ubsoft_turnstile.ino").read_text(encoding="utf-8-sig")
visitor = source.split("// BEGIN COMMAND_MESSAGE_VISITOR", 1)[1].split("// END COMMAND_MESSAGE_VISITOR", 1)[0]
test = Path("test/firmware/command_messages.cpp").read_text(encoding="utf-8")
folder = Path("build/firmware-command-tests")
folder.mkdir(parents=True, exist_ok=True)
unit = folder / "command_messages.cpp"
unit.write_text(test.replace("// VISITOR_INSERTION_POINT", visitor), encoding="utf-8")
if not options.extract_only:
    compiler = shutil.which("g++") or shutil.which("clang++")
    if not compiler:
        raise SystemExit("Host C++ compiler required; CI runs this test on Ubuntu.")
    executable = folder / "command_messages_test"
    subprocess.run([compiler, "-std=c++17", "-Wall", "-Wextra", "-I", options.include, str(unit), "-o", str(executable)], check=True)
    subprocess.run([str(executable.resolve())], check=True)
