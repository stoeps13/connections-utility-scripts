# Db2 Database Migration Scripts

These scripts support a Windows-to-Linux Db2 logical migration using `db2move`. This example
migrates HCL Connections from 6.0CR5 to 8.0CR15.

## `db2export.bat`

Runs on the Windows source server from a **Db2 Command Window**.

It:

- Finds database aliases in the current Db2 database directory
- Creates one export directory per database
- Runs `db2move <database> export`
- Writes a separate `db2move-export.log` for each database

Edit the export root in the script if required:

```bat set "EXPORT_ROOT=D:\migration\db2export" ```

Optional authentication:

```bat
set DB2_USER=source_user 
set DB2_PASSWORD=source_password 
```

Run:

```bat
db2export.bat
```

For the final migration, stop or quiesce Connections/WebSphere first. Keep every generated file,
including `db2move.lst`, IXF files, LOB files, and message files.

Copy the exported files to the new Linux DB2 host.

## `import-db2.sh`

Runs on the Linux target as the Db2 instance owner, normally `db2inst1`.

The script:

1. Creates each target database using the selected HCL Connections schema scripts.
2. Runs the configured pre-transfer scripts.
3. Imports the corresponding `db2move` export.
4. Runs post-transfer and upgrade scripts.
5. Continues after SQL and import warnings and prints a summary at the end.

It is destructive: it can drop target databases. Set the required confirmation variable:

```bash 
export DROP_DATABASES=YES 
```

Optional variables:

```bash 
export ROOT=/opt/migration 
export DBSRC=6.0IFR1-connections.sql 
export DBTGT=8.0-connections.sql 
export BCKP=db2export 
export DB_USER=db2inst1 export
DB_PASSWORD='password' 
```

If `DB_PASSWORD` is not set, the script prompts for it.

Run:

```bash 
chmod 700 import-db2.sh 
sudo -iu db2inst1 
cd /path/to/scripts 
DROP_DATABASES=YES ./import-db2.sh 2>&1 | tee import-db2.log 
```

## Important notes

- Use HCL scripts matching the exact source Connections release and fix level.
- The target schema must match the source schema during `db2move` import. Apply Connections upgrades afterward.
- SQL entries use either `at|file.sql` for `@` terminators or `semicolon|file.sql` for normal semicolons.
- Review every warning. The script continues after SQL errors because some pre-transfer scripts attempt to remove objects that may not exist, but required schema and upgrade errors must be corrected.
- Validate row counts, column order, constraints, schema-version tables, LOB data, and application behavior before cutover.
- Do not start Connections until the target database schemas and upgrade scripts have completed successfully.

### Check Blogs, Files and Wikis database

- During the migration I had issues with `FILES.PRODUCT`, `WIKIS.PRODUCT` and `BLOGS.WEBSITE`
- The product tables had mixed entries, mainly mode=`on-premise` was missing

#### Fix `BLOGS.WEBSITE`

```sql
CONNECT TO BLOGS;
INSERT INTO BLOGS.WEBSITE (ID, NAME, HANDLE, DESCRIPTION, USERID, DEFAULTPAGEID, WEBLOGDAYID, ENABLEBLOGGERAPI, EDITORPAGE, ALLOWCOMMENTS, EMAILCOMMENTS, EDITORTHEME, "LOCALE", TIMEZONE, DEFAULTPLUGINS, ISENABLED, ISACTIVE, DATECREATED, DEFAULTALLOWCOMMENTS, DEFAULTDISPLAYVOTERS, DEFAULTCOMMENTDAYS, COMMENTMOD, DISPLAYCNT, LASTMODIFIED, PAGEMODELS, ENABLEMULTILANG, SHOWALLLANGS, DBMODTIME, SDBMODTIME, ATOMID, SITE_TYPE, ALLOW_COEDIT, STATUS, VOTEMAX, GRADUATEDALLOWCOMMENTS, GRADUATEDALLOWVOTE, ORG_ID) VALUES('wwwwwwww-0137-42cd-81d4-4370ae782ac7', 'homepage', 'homepage', 'homepage', 'uuuuuuuu-0137-42cd-81d4-4370ae782ac7', 'dummy', 'dummy', 0, NULL, 1, 0, 'homepage', 'en_US', 'America/New_York', NULL, 1, 1, '2026-05-12 16:39:09.985000', 1, 0, 7, 0, 0, '2026-05-12 16:39:09.985000', NULL, 0, 1, '2026-05-12 16:39:09.985940', '2026-05-12 16:39:09.985000', 'urn:lsid:ibm.com:blogs:blog-wwwwwwww-0137-42cd-81d4-4370ae782ac7', 0, 0, 0, 0, 0, 0, 'a');
COMMIT;
CONNECT RESET;
```

#### Fix `FILES.PRODUCT`

```sql
CONNECT TO FILES;
UPDATE FILES.PRODUCT SET VERSION_MAJOR=6, VERSION_MINOR=0, VERSION_MILLI=0, VERSION_MICRO=0, BUILD_NUMBER='20221018-2149', SCHEMA_VERSION='147', PRESCHEMAVER='0', POSTSCHEMAVER='147.3', "MODE"='on-premise' WHERE ID='connections.files';
COMMIT;
CONNECT RESET;
```

#### Fix `WIKIS.PRODUCT`

```sql
CONNECT TO WIKIS;
UPDATE WIKIS.PRODUCT SET VERSION_MAJOR=6, VERSION_MINOR=0, VERSION_MILLI=0, VERSION_MICRO=0, BUILD_NUMBER='20221018-2149', SCHEMA_VERSION='147', PRESCHEMAVER='0', POSTSCHEMAVER='147.3', "MODE"='on-premise' WHERE ID='connections.wikis';
COMMIT;
CONNECT RESET;
```
