@echo off
REM DarkLoot 测试运行器 - 相对路径定位 Godot 与工程
REM 目录结构: <root>/tools/run_tests.bat, <root>/project/src/, Godot 在 <root>/../tools/
REM %~dp0 = 本 bat 所在目录(以 \ 结尾)

set "GODOT=%~dp0..\..\tools\Godot_v4.3-stable_win64.exe"
set "PROJECT_SRC=%~dp0..\project\src"

if not exist "%GODOT%" (
    echo [run_tests] 找不到 Godot: %GODOT%
    echo 请确认 Godot_v4.3-stable_win64.exe 在 tools 目录
    exit /b 1
)

REM 不加 --quit: test_runner 是 SceneTree, 跑完测试自行 quit
"%GODOT%" --headless --path "%PROJECT_SRC%" -s res://tests/test_runner.gd
