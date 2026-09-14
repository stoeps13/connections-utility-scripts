#!/usr/bin/env bash

set -euo pipefail

usage() {
   echo "Usage: $0 --source-dir SOURCE_DIR --target-dir TARGET_DIR [--dry-run]"
}

SOURCE_DIR=""
TARGET_DIR=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
   case "$1" in
      --source-dir)
         [[ $# -ge 2 ]] || { echo "Missing value for --source-dir" >&2; usage >&2; exit 2; }
         SOURCE_DIR="$2"
         shift 2
         ;;
      --target-dir)
         [[ $# -ge 2 ]] || { echo "Missing value for --target-dir" >&2; usage >&2; exit 2; }
         TARGET_DIR="$2"
         shift 2
         ;;
      --dry-run)
         DRY_RUN=true
         shift
         ;;
      -h|--help)
         usage
         exit 0
         ;;
      *)
         echo "Unknown option: $1" >&2
         usage >&2
         exit 2
         ;;
   esac
done

if [[ -z "$SOURCE_DIR" || -z "$TARGET_DIR" ]]; then
   echo "Both --source-dir and --target-dir are required." >&2
   usage >&2
   exit 2
fi

echo "Source directory: $SOURCE_DIR"
echo "Target directory: $TARGET_DIR"

if "$DRY_RUN"; then
   echo "Mode: dry run (no files will be copied)"
else
   read -r -p "Continue and copy these directories? [y/N] " answer
   [[ "$answer" =~ ^[Yy]$ ]] || { echo "Copy cancelled."; exit 0; }
fi

DATE=$(date +%Y%m%d_%H%M)

# cnx_dir=("activities/content" "blogs/upload" "boards/properties" "dogear/favorite" "files/upload" "forums/content" "icxt" "invite" "wikis/upload")
cnx_dir=("activities/content" "blogs/upload" "dogear/favorite" "files/upload" "forums/content" "wikis/upload")

for i in "${cnx_dir[@]}"; do
   APP=${i//\//_}
   echo "$APP"
   rsync_args=(--log-file="${DATE}-sync-${APP}.log" -azP)
   "$DRY_RUN" && rsync_args+=(--dry-run)
   rsync "${rsync_args[@]}" "$SOURCE_DIR/$i/" "$TARGET_DIR/$i/"
done
