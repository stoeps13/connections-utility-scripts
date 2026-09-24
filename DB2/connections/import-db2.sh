#!/usr/bin/env bash
# Import HCL Connections Db2 databases from db2move exports.
#
# Required before running:
#   export DROP_DATABASES=YES
#
# Optional overrides:
#   ROOT=/opt/migration
#   DBSRC=6.0IFR1-connections.sql
#   DBTGT=8.0-connections.sql
#   BCKP=db2export
#   DB_USER=db2inst1
#   DB_PASSWORD='password'

set -Eeuo pipefail

ROOT="${ROOT:-/opt/migration}"
DBSRC="${DBSRC:-6.0IFR1-connections.sql}"
DBTGT="${DBTGT:-8.0-connections.sql}"
BCKP="${BCKP:-db2export}"
DB_USER="${DB_USER:-db2inst1}"
CURRENT_SQL_FILE=""
WARNINGS=()

log() {
    printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

warn() {
    WARNINGS+=("$*")
    printf 'WARNING: %s\n' "$*" >&2
}

cleanup() {
    db2 terminate >/dev/null 2>&1 || true
}

on_error() {
    local rc=$?
    printf 'ERROR: command failed with exit code %s\n' "$rc" >&2
    printf 'ERROR: line %s: %s\n' "${BASH_LINENO[0]}" "${BASH_COMMAND}" >&2
    if [[ -n "$CURRENT_SQL_FILE" ]]; then
        printf 'ERROR: SQL file: %s\n' "$CURRENT_SQL_FILE" >&2
    fi
    exit "$rc"
}

trap cleanup EXIT
trap on_error ERR

[[ "${DROP_DATABASES:-}" == "YES" ]] || \
    die "This script drops databases. Set DROP_DATABASES=YES to continue."

if [[ -z "${DB_PASSWORD:-}" ]]; then
    read -r -s -p "Db2 password for ${DB_USER}: " DB_PASSWORD
    echo
fi

# Run one SQL script.
# mode=at        means: db2 -td@ -v -f file
# mode=semicolon means: db2 -t -v -f file, equivalent to db2 -tvf file
run_sql() {
    local file="$1"
    local mode="${2:-at}"

    [[ -f "$file" ]] || die "SQL file not found: $file"

    CURRENT_SQL_FILE="$file"
    log "Running $file"

    local rc=0

    case "$mode" in
        at)
            db2 -td@ -v -f "$file" || rc=$?
            ;;
        semicolon)
            db2 -t -v -f "$file" || rc=$?
            ;;
        *)
            die "Unknown SQL terminator mode '$mode' for $file"
            ;;
    esac

    if ((rc != 0)); then
        warn "SQL script returned exit code $rc; continuing: $file"
    fi

    CURRENT_SQL_FILE=""
}

# Run entries formatted as: mode|file
# Examples: at|createDb.sql, semicolon|predbxfer60.sql
run_sql_list() {
    local base="$1"
    shift

    local spec mode file path

    for spec in "$@"; do
        mode="${spec%%|*}"
        file="${spec#*|}"

        if [[ "$file" = /* ]]; then
            path="$file"
        else
            path="$base/$file"
        fi

        run_sql "$path" "$mode"
    done
}

migrate_db() {
    local dbname="$1"
    local folder="$2"
    shift 2

    local source_dir="$ROOT/$DBSRC/$folder/db2"
    local target_dir="$ROOT/$DBTGT/$folder/db2"
    local backup_dir="$ROOT/$BCKP/$dbname"

    # These arrays contain entries in the form: terminator|filename
    local -a source_sql=(
        "at|createDb.sql"
        "at|appGrants.sql"
    )
    local -a before_pre_sql=()
    local -a pre_sql=()
    local -a post_sql=()
    local -a after_post_sql=()

    while (($#)); do
        case "$1" in
            --source-sql|--before-pre-sql|--pre-sql|--post-sql|--after-post-sql)
                [[ $# -ge 2 ]] || die "Missing argument after $1 for $dbname"
                case "$1" in
                    --source-sql)      source_sql+=("$2") ;;
                    --before-pre-sql)  before_pre_sql+=("$2") ;;
                    --pre-sql)         pre_sql+=("$2") ;;
                    --post-sql)        post_sql+=("$2") ;;
                    --after-post-sql)  after_post_sql+=("$2") ;;
                esac
                shift 2
                ;;
            *)
                die "Unknown option for $dbname: $1"
                ;;
        esac
    done

    log "Migrating $dbname ($folder)"

    [[ -d "$source_dir" ]] || die "Source script directory not found: $source_dir"
    [[ -d "$target_dir" ]] || die "Target script directory not found: $target_dir"
    [[ -d "$backup_dir" ]] || die "Backup directory not found: $backup_dir"
    [[ -f "$backup_dir/db2move.lst" ]] || \
        die "db2move.lst not found in $backup_dir"

    if db2 list database directory 2>/dev/null | awk -v db="$dbname" -F= '
        /Database alias/ {
            alias = $2
            gsub(/[[:space:]]/, "", alias)
            if (toupper(alias) == toupper(db)) found = 1
        }
        END { exit(found ? 0 : 1) }
    '; then
        log "Dropping database $dbname"
        db2 drop database "$dbname"
    else
        log "Database $dbname is not cataloged; skipping drop"
    fi

    run_sql_list "$source_dir" "${source_sql[@]}"
    run_sql_list "$target_dir" "${before_pre_sql[@]}"
    run_sql_list "$source_dir" "${pre_sql[@]}"

    log "Importing data into $dbname"
    pushd "$backup_dir" >/dev/null
    local import_rc=0
    db2move "$dbname" import -u "$DB_USER" -p "$DB_PASSWORD" || import_rc=$?
    popd >/dev/null

    if ((import_rc != 0)); then
        warn "db2move import for $dbname returned exit code $import_rc; continuing"
    fi

    run_sql_list "$target_dir" "${post_sql[@]}"
    run_sql_list "$target_dir" "${after_post_sql[@]}"

    log "Completed $dbname"
}

# Activities
migrate_db OPNACT activities \
    --pre-sql "semicolon|$ROOT/$DBTGT/activities/db2/predbxfer60.sql" \
    --post-sql "semicolon|$ROOT/$DBTGT/activities/db2/postdbxfer60.sql"

# Blogs
migrate_db BLOGS blogs \
    --pre-sql "at|$ROOT/$DBTGT/blogs/db2/predbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/blogs/db2/postdbxfer60.sql"

# Communities
migrate_db SNCOMM communities \
    --source-sql "at|$ROOT/$DBTGT/communities/db2/calendar-createDb.sql" \
    --source-sql "at|$ROOT/$DBTGT/communities/db2/calendar-appGrants.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/communities/db2/upgrade-60-60CR2.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/communities/db2/upgrade-60CR2-60CR4.sql" \
    --pre-sql "at|$ROOT/$DBTGT/communities/db2/calendar-predbxfer60.sql" \
    --pre-sql "at|$ROOT/$DBTGT/communities/db2/predbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/communities/db2/postdbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/communities/db2/calendar-postdbxfer60.sql"

# Bookmarks
migrate_db DOGEAR dogear \
    --pre-sql "at|$ROOT/$DBTGT/dogear/db2/predbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/dogear/db2/postdbxfer60.sql"

# Files
migrate_db FILES files \
    --before-pre-sql "at|$ROOT/$DBTGT/files/db2/upgrade-60-60CR2.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/files/db2/upgrade-60CR2-60CR4.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/files/db2/upgrade-60CR4-60CR5.sql" \
    --pre-sql "at|$ROOT/$DBTGT/files/db2/predbxfer60CR5.sql" \
    --post-sql "at|$ROOT/$DBTGT/files/db2/postdbxfer60CR5.sql" \
    --after-post-sql "at|$ROOT/$DBTGT/files/db2/upgrade-65-65CR1.sql"

# Forums
migrate_db FORUM forum \
    --pre-sql "semicolon|$ROOT/$DBTGT/forum/db2/predbxfer60.sql" \
    --post-sql "semicolon|$ROOT/$DBTGT/forum/db2/postdbxfer60.sql"

# Homepage
migrate_db HOMEPAGE homepage \
    --before-pre-sql "at|$ROOT/$DBTGT/homepage/db2/upgrade-60CR1-60CR2.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/homepage/db2/upgrade-60CR2-60CR3.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/homepage/db2/upgrade-60CR3-60CR4.sql" \
    --pre-sql "at|$ROOT/$DBTGT/homepage/db2/predbxfer60CR3.sql" \
    --post-sql "at|$ROOT/$DBTGT/homepage/db2/postdbxfer60CR2.sql" \
    --after-post-sql "at|$ROOT/$DBTGT/homepage/db2/upgrade-60CR4-70.sql"
    
# Metrics
migrate_db METRICS metrics \
    --before-pre-sql "at|$ROOT/$DBTGT/metrics/db2/upgrade-60-60CR2.sql" \
    --pre-sql "at|$ROOT/$DBTGT/metrics/db2/predbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/metrics/db2/postdbxfer60.sql"
    
# Mobile
migrate_db MOBILE mobile \
    --pre-sql "at|$ROOT/$DBTGT/mobile/db2/predbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/mobile/db2/postdbxfer60.sql" \
    --after-post-sql "at|$ROOT/$DBTGT/mobile/db2/upgrade-65-65CRX.sql"
    
# Profiles
migrate_db PEOPLEDB profiles \
    --pre-sql "at|$ROOT/$DBTGT/profiles/db2/predbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/profiles/db2/postdbxfer60.sql" \
    --after-post-sql "at|$ROOT/$DBTGT/profiles/db2/upgrade-60-80.sql"
    
# Pushnotifications
migrate_db PNS pushnotification \
    --pre-sql "at|$ROOT/$DBTGT/pushnotification/db2/predbxfer60.sql" \
    --post-sql "at|$ROOT/$DBTGT/pushnotification/db2/postdbxfer60.sql" 
    
# Wikis
migrate_db WIKIS wikis \
    --before-pre-sql "at|$ROOT/$DBTGT/wikis/db2/upgrade-60-60CR2.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/wikis/db2/upgrade-60CR2-60CR4.sql" \
    --before-pre-sql "at|$ROOT/$DBTGT/wikis/db2/upgrade-60CR4-60CR5.sql" \
    --pre-sql "at|$ROOT/$DBTGT/wikis/db2/predbxfer60CR5.sql" \
    --post-sql "at|$ROOT/$DBTGT/wikis/db2/postdbxfer60CR5.sql" \
    --after-post-sql "at|$ROOT/$DBTGT/wikis/db2/upgrade-65-65CR1.sql"
    
log "All database migration steps completed"
if ((${#WARNINGS[@]} > 0)); then
    echo
    echo "Warnings requiring review:"
    printf ' - %s\n' "${WARNINGS[@]}"
else
    log "No warnings were recorded"
fi
