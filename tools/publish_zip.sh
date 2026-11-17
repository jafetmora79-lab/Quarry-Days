#!/usr/bin/env bash
# Builds the Windows pack, zips EXE + PCK (+ launcher), updates the game-zip branch and the Desktop folder.   usage: tools/publish_zip.sh "<commit message>"
set -e
cd "$(dirname "$0")/.."
S=/c/Users/Themo/AppData/Local/Temp/claude/a5a0ab546012893a/01c83728-4c23-4f4a-b70a-966ac2cae09c/scratchpad
G="$S/godot43/Godot_v4.3-stable_win64.exe"
rm -rf build/pkg_final && mkdir -p build/pkg_final/QuarryDays
"$G" --headless --path . --export-pack "Windows Desktop" build/pkg_final/QuarryDays/QuarryDays.pck 2>&1 | tail -1
cp build/QuarryDays.exe build/pkg_final/QuarryDays/
printf '@echo off\r\nstart "" "%%~dp0QuarryDays.exe" res://TerrainArena.tscn\r\n' > build/pkg_final/QuarryDays/TerrainArena.bat
cd build/pkg_final/QuarryDays
echo "boot script errors: $(XDG_DATA_HOME="$S/fresh_pub" APPDATA="$S/fresh_pub" timeout 60 ./QuarryDays.exe --headless --quit-after 200 2>&1 | grep -ciE 'script error' || true)"
powershell -c "Compress-Archive -Force -Path '$(cygpath -w $PWD)\QuarryDays.exe','$(cygpath -w $PWD)\QuarryDays.pck','$(cygpath -w $PWD)\TerrainArena.bat' -DestinationPath '$(cygpath -w $S)\gz\QuarryDays_latest.zip'"
cp QuarryDays.pck TerrainArena.bat "/c/Users/Themo/Desktop/Quarry Days (latest)/"
cd "$S/gz" && git add -A && git commit -q -m "${1:-Latest build}" && git push -q https://github.com/jafetmora79-lab/Quarry-Days.git game-zip 2>&1 | tail -1 || true
echo published
