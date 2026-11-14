#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/schneetag-checks.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
export SNOW_TEST_OUTPUT="$test_dir"
python3 - "$source_dir" "$test_dir" <<'PY'
from pathlib import Path
import sys
source, output = map(Path, sys.argv[1:])
code = (source / 'main.swift').read_text().rsplit('\nlet app = NSApplication.shared', 1)[0]
checks = (source / 'Tests/PhysicsChecks.swift').read_text()
(output / 'main.swift').write_text(code + '\n' + checks)
PY
opt=-O
if [[ "${SNOW_CHECK_DEBUG:-0}" == 1 ]]; then opt=-g; fi
xcrun swiftc "$opt" "$test_dir/main.swift" "$source_dir/BannerFrost.swift" "$source_dir/FestiveCursor.swift" "$source_dir/HeavyPlow.swift" "$source_dir/SnowWorkshop.swift" "$source_dir/SnowmanArt.swift" "$source_dir/SleighArt.swift" "$source_dir/Advent.swift" "$source_dir/SnowballFight.swift" "$source_dir/ChristmasScene.swift" -o "$test_dir/physics-checks"
"$test_dir/physics-checks"
