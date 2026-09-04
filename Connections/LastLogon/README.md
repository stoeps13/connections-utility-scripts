# Export of DB2 tables to txt

Simple way to get the last logon time of all users, please be sure that this is not against the "data privacy protection" in your company!

You can chart and interpret these text files through a spreadsheet program.

On Linux/Unix, run `./getDBInfo.sh` from a DB2-initialized shell. The shell script limits each DB2 command to 60 seconds; set `DB2_TIMEOUT_SECONDS` to change this. On Windows, run `getDBInfo.bat` from a DB2 Command Window. The script prompts for the `lcuser` password with hidden input, creates a `results` folder, and writes all output files there. PowerShell must be available (it is included with supported Windows versions). The password is passed to DB2 in single quotes so special characters are supported. To avoid the prompt, define the `DB2_PASSWORD` environment variable before running the script, for example: `set "DB2_PASSWORD=your-password"`.
