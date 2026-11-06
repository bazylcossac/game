#!/bin/sh
# Compiles the project and prints only real errors. Usage: tools/check.sh [seconds]
G="/c/Users/stroj/Godot/Godot_v4.7.2-stable_win64_console.exe"
cd "$(dirname "$0")/.."
"$G" --headless --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|ERROR:|   at: " | grep -v "first_scan" | head -40
