@echo off
rem This bat locates everything relative to its own folder (%~dp0)
rem so it never needs to contain any Chinese characters.

set "GODOT=%~dp0..\..\tools\Godot_v4.3-stable_win64.exe"
set "PROJECT=%~dp0src"

if not exist "%GODOT%" (
    echo [ERROR] Godot not found at: %GODOT%
    pause
    exit /b
)

if not exist "%PROJECT%\project.godot" (
    echo [ERROR] project.godot not found at: %PROJECT%
    pause
    exit /b
)

echo Launching DarkLoot ARPG ...
start "" "%GODOT%" --path "%PROJECT%"
