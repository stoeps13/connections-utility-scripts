@echo off

REM Author: Christoph Stoettner
REM E-Mail: christoph.stoettner@stoeps.de
REM License: Apache 2.0

setlocal

rem Run this script from a DB2 Command Window.
cd /d "%~dp0"
if not exist "results" mkdir "results"

if not defined DB2_PASSWORD for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "$p=Read-Host 'Enter password for lcuser' -AsSecureString; $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); try {[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)} finally {[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)}"`) do set "DB2_PASSWORD=%%P"
if not defined DB2_PASSWORD (
    echo A password is required.
    exit /b 1
)

echo.
call :query "sncomm" "select LASTLOGIN,EMAIL,DISPLAY from SNCOMM.MEMBERPROFILE WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN" "communities.txt" || exit /b 1
call :query "homepage" "SELECT LAST_UPDATE,USER_MAIL,DISPLAYNAME from HOMEPAGE.PERSON WHERE LAST_UPDATE IS NOT NULL ORDER BY LAST_UPDATE" "homepage.txt" || exit /b 1
call :query "opnact" "SELECT LASTLOGIN,EMAIL,MEMBERDISP from ACTIVITIES.OA_MEMBERPROFILE WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN" "opnact.txt" || exit /b 1
call :query "blogs" "SELECT LASTLOGIN,EMAILADDRESS,FULLNAME from BLOGS.ROLLERUSER WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN" "blogs.txt" || exit /b 1
call :query "wikis" "SELECT LAST_VISIT,EMAIL,NAME from WIKIS.USER WHERE LAST_VISIT IS NOT NULL ORDER BY LAST_VISIT" "wikis.txt" || exit /b 1
call :query "files" "SELECT LAST_VISIT,EMAIL,NAME from FILES.USER WHERE LAST_VISIT IS NOT NULL ORDER BY LAST_VISIT" "files.txt" || exit /b 1
call :query "dogear" "SELECT LASTLOGIN,EMAIL,DISPLAYNAME from DOGEAR.PERSON WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN" "dogear.txt" || exit /b 1
call :query "forum" "SELECT LASTLOGIN,EMAIL,MEMBERDISP from FORUM.DF_MEMBERPROFILE WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN" "forums.txt" || exit /b 1

echo.
echo Query output was written to "%~dp0results".
exit /b 0

:query
set "database=%~1"
set "sql=%~2"
set "output=%~3"

echo Querying %database%...
rem Use DB2 single quotes so special characters are treated as password data.
db2 "connect to %database% user lcuser using '%DB2_PASSWORD%'"
if errorlevel 1 (
    echo ERROR: Could not connect to %database%.
    exit /b 1
)
db2 "%sql%" > "results\%output%"
if errorlevel 1 (
    rem DB2 can return a non-zero code for a valid empty result set.
    findstr /c:"0 record(s) selected" "results\%output%" >nul
    if errorlevel 1 (
        echo ERROR: Query failed for %database%. See results\%output%.
        exit /b 1
    )
    echo No records found for %database%.
)
db2 "connect reset"
if errorlevel 1 (
    echo ERROR: Could not reset the connection for %database%.
    exit /b 1
)
exit /b 0
