#!/usr/bin/env bash

# Author: Christoph Stoettner
# E-Mail: christoph.stoettner@stoeps.de
# License: Apache 2.0

# Run this script from a DB2-initialized shell.
set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"
mkdir -p results

if [[ -z "${DB2_PASSWORD:-}" ]]; then
    read -r -s -p "Enter password for lcuser: " DB2_PASSWORD
    echo
fi

if [[ -z "$DB2_PASSWORD" ]]; then
    echo "A password is required." >&2
    exit 1
fi

run_db2() {
    timeout "${DB2_TIMEOUT_SECONDS:-60}" db2 "$@"
}

query() {
    local database=$1
    local sql=$2
    local output=$3
    local output_path="results/$output"

    echo "Querying $database..."
    if ! run_db2 "connect to $database user lcuser using '$DB2_PASSWORD'"; then
        echo "ERROR: Could not connect to $database." >&2
        return 1
    fi

    run_db2 "$sql" > "$output_path" 2>&1
    local query_status=$?
    if (( query_status != 0 )) && ! grep -q "0 record(s) selected" "$output_path"; then
        echo "ERROR: Query failed for $database. See $output_path." >&2
        return 1
    fi
    if grep -q "0 record(s) selected" "$output_path"; then
        echo "No records found for $database."
    fi

    if ! run_db2 "connect reset"; then
        echo "ERROR: Could not reset the connection for $database." >&2
        return 1
    fi
}

databases=(sncomm homepage opnact blogs wikis files dogear forums)
outputs=(communities.txt homepage.txt opnact.txt blogs.txt wikis.txt files.txt dogear.txt forums.txt)
sql=(
    "select LASTLOGIN,EMAIL,DISPLAY from SNCOMM.MEMBERPROFILE WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN"
    "SELECT LAST_UPDATE,USER_MAIL,DISPLAYNAME from HOMEPAGE.PERSON WHERE LAST_UPDATE IS NOT NULL ORDER BY LAST_UPDATE"
    "SELECT LASTLOGIN,EMAIL,MEMBERDISP from ACTIVITIES.OA_MEMBERPROFILE WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN"
    "SELECT LASTLOGIN,EMAILADDRESS,FULLNAME from BLOGS.ROLLERUSER WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN"
    "SELECT LAST_VISIT,EMAIL,NAME from WIKIS.USER WHERE LAST_VISIT IS NOT NULL ORDER BY LAST_VISIT"
    "SELECT LAST_VISIT,EMAIL,NAME from FILES.USER WHERE LAST_VISIT IS NOT NULL ORDER BY LAST_VISIT"
    "SELECT LASTLOGIN,EMAIL,DISPLAYNAME from DOGEAR.PERSON WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN"
    "SELECT LASTLOGIN,EMAIL,MEMBERDISP from FORUM.DF_MEMBERPROFILE WHERE LASTLOGIN IS NOT NULL ORDER BY LASTLOGIN"
)

for i in "${!databases[@]}"; do
    query "${databases[$i]}" "${sql[$i]}" "${outputs[$i]}" || exit 1
done

echo "Query output was written to $SCRIPT_DIR/results"
