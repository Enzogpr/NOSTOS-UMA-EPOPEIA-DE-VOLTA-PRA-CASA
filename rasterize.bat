@echo off
setlocal enabledelayedexpansion

rem ---------- CONFIGURATION ----------
set "ROOT=%~dp0"
set "REI_DIR=%ROOT%Assets\rei_de_troia\attacks_animations"
set "ODISSEU_DIR=%ROOT%Assets\odisseu\attacks_animations"
set REI_W=85
set REI_H=160
set ODISSEU_W=614
set ODISSEU_H=724

rem ---------- MAIN ----------
echo.
echo === Starting resize of REI attack animations (%REI_W%x%REI_H%) ===
call :resize_folder "%REI_DIR%" %REI_W% %REI_H%

echo.
echo === Starting resize of ODISSEU attack animations (%ODISSEU_W%x%ODISSEU_H%) ===
call :resize_folder "%ODISSEU_DIR%" %ODISSEU_W% %ODISSEU_H%

echo.
echo All done!
pause
goto :eof

rem ---------- SUBROUTINE ----------
:resize_folder
set "FOLDER=%~1"
set "W=%~2"
set "H=%~3"

for %%F in ("%FOLDER%\*.png") do (
    set "TMPFILE=%%~dpF_tmp_%%~nxF"
    echo   Resizing: %%~nxF
    ffmpeg -y -loglevel error -i "%%F" -vf "scale=%W%:%H%:force_original_aspect_ratio=disable" "!TMPFILE!"
    if exist "!TMPFILE!" (
        move /Y "!TMPFILE!" "%%F" >nul
        echo   [OK] %%~nxF
    ) else (
        echo   [ERROR] Failed to resize %%~nxF
    )
)
exit /b
