@echo off
rem Serwer dedykowany bez grafiki, tak samo jak pozniej na VPS. Zamknij okno, aby go wylaczyc.
rem TRYB: podboj, pvp, deathmatch, czolgi
rem MAPA: stare_miasto, pole_bitwy, rynek, ziemia_niczyja, neonowa_dzielnica, stacja_rdzen, dolina_pancerna. Puste oznacza domyslna mape trybu.
rem Sami gracze, bez botow. Boty wlaczy --bots=12 --difficulty=1.
set TRYB=podboj
set MAPA=
"C:\Users\stroj\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." -- --server --port=7777 --mode=%TRYB% --map=%MAPA%
pause
