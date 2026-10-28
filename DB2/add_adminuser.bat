REM Needed for variable expansion
SETLOCAL ENABLEDELAYEDEXPANSION
REM Check System Language

set TOKEN=3
REM get all databases of db2 instance and loop through the list
FOR /F "tokens=%TOKEN% delims== " %%a IN ('DB2CMD.EXE -c -w -i DB2 list DATABASE DIRECTORY ^| findstr /i "Alias"') DO (
				set DATABASES=%%a,!DATABASES!
				title Add admin to db %%a on %date% at %time%...
				DB2 "connect to %%a"
				DB2 "GRANT DBADM ON DATABASE TO USER db2admin"
				DB2 "commit"
				DB2 "connect reset"
				)
ECHO Successfull created db2admin for %DATABASES% in %DBBACKUPPATH%a
