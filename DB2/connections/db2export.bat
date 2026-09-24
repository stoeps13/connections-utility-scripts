@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Export all databases cataloged in the current Db2 instance.
rem Run this from a Db2 Command Window with the source environment quiesced.
rem
rem Optional authentication:
rem   set DB2_USER=source_user
rem   set DB2_PASSWORD=source_password
rem If these variables are not set, Db2 uses the current authentication context.

set "EXPORT_ROOT=C:\db2move"
set "AUTH_ARGS="

if defined DB2_USER set "AUTH_ARGS=-u %DB2_USER%"
if defined DB2_PASSWORD set "AUTH_ARGS=!AUTH_ARGS! -p %DB2_PASSWORD%"

if not exist "%EXPORT_ROOT%" mkdir "%EXPORT_ROOT%"

set "FOUND_DATABASE=0"

for /f "tokens=2 delims==" %%D in ('db2 list database directory ^| findstr /R /C:"^[ ]*Database alias"') do for /f "tokens=1" %%E in ("%%D") do (
    set "FOUND_DATABASE=1"
    set "DB_ALIAS=%%E"
    set "DB_DIR=!EXPORT_ROOT!\!DB_ALIAS!"

    echo.
    echo ================================================================
    echo Exporting database alias: !DB_ALIAS! to !DB_DIR!
    echo ================================================================

    if not exist "!DB_DIR!\." mkdir "!DB_DIR!"

    if not exist "!DB_DIR!\." (
        echo ERROR: export directory is unavailable: !DB_DIR!
    ) else (
        pushd "!DB_DIR!"
        db2move !DB_ALIAS! export !AUTH_ARGS! > db2move-export.log 2>&1
        set "EXPORT_RC=!errorlevel!"
        popd

        if not "!EXPORT_RC!"=="0" (
            echo ERROR: export failed for !DB_ALIAS!. See:
            echo        !DB_DIR!\db2move-export.log
        ) else (
            echo Export completed for !DB_ALIAS!.
        )
    )
)

if "%FOUND_DATABASE%"=="0" (
    echo ERROR: No database aliases were found.
    echo Check that this is a Db2 Command Window and that the Db2 output is English.
    exit /b 1
)

db2 terminate
endlocal
exit /b 0
