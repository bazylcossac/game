@echo off
rem Serwer dedykowany bez grafiki, tak samo jak pozniej na VPS. Zamknij okno, aby go wylaczyc.
rem TRYB: podboj, pvp, deathmatch, czolgi, bomba
rem MAPA: stare_miasto, pole_bitwy, rynek, fabryka. Puste oznacza domyslna mape trybu.
set TRYB=podboj
set MAPA=
"C:\Users\stroj\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." -- --server --port=7777 --mode=%TRYB% --map=%MAPA% --bots=12 --difficulty=1
pause
