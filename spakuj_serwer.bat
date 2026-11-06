@echo off
rem Tworzy folder paczka_vps z tym, co trzeba skopiowac na VPS.
cd /d "%~dp0"
if exist paczka_vps rmdir /s /q paczka_vps
mkdir paczka_vps
tar -czf paczka_vps\miecz-dawida-serwer.tar.gz project.godot main.tscn scripts shaders assets
copy /y deploy\install.sh paczka_vps\ >nul
copy /y deploy\miecz-dawida.service paczka_vps\ >nul
copy /y deploy\miecz-dawida.env paczka_vps\ >nul
echo.
echo Gotowe: folder paczka_vps. Skopiuj go na VPS i uruchom: sudo bash install.sh
pause
