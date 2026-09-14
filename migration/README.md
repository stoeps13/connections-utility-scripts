# Copy the HCL Connections shared directory

Use these scripts to copy HCL Connections attachment and content directories with `rsync`. Mount the source filesystem read-only before you copy.

## Prerequisites

- Install `rsync`.
- Run the commands as a user who can read the source and write to the target.
- Stop or quiesce Connections so files do not change during the copy.
- Confirm the source and target filesystems before you start. The scripts do not delete target-only files.

## Mount the source read-only

Mount the old Connections shared filesystem at a local mount point. For example:

```sh
sudo mount -o ro SOURCE_DEVICE /mnt/connections-old
mount | grep /mnt/connections-old
```

Replace `SOURCE_DEVICE` with the block device, NFS export, or other mount source for your environment. Confirm that the mount is read-only before you continue.

## Choose a script

### `rsync_shared_dir_options.sh`

Use this script when you need to specify the source and target paths. It asks for confirmation, supports a dry run, and copies these directories:

- `activities/content`
- `blogs/upload`
- `dogear/favorite`
- `files/upload`
- `forums/content`
- `wikis/upload`

Make the script executable if needed:

```sh
chmod +x rsync_shared_dir_options.sh
```

Run a dry run first:

```sh
./rsync_shared_dir_options.sh \
  --source-dir /mnt/connections-old/data \
  --target-dir /mnt/connections/data \
  --dry-run
```

Run the copy after you review the dry-run output:

```sh
./rsync_shared_dir_options.sh \
  --source-dir /mnt/connections-old/data \
  --target-dir /mnt/connections/data
```

The script prompts you before a real copy. Enter `y` to continue. Each `rsync` invocation writes a timestamped log in the current directory, for example `20250131_1430-sync-activities_content.log`.

### `rsync_shared_dir.sh`

Use this script with the default paths:

```text
Source: /mnt/connections-old/data
Target: /mnt/connections/data
```

Run it with:

```sh
chmod +x rsync_shared_dir.sh
./rsync_shared_dir.sh
```

This script does not prompt for confirmation and does not support a dry run. Edit `SOURCE_DIR`, `TARGET_DIR`, or the `cnx_dir` list if your layout differs.

## Rsync behavior

Both scripts use `rsync -azP`:

- archive mode preserves filesystem metadata where permitted;
- compression reduces transfer size;
- progress information appears during the transfer;
- `rsync` updates target files when their contents or metadata differ;
- `rsync` leaves target-only files in place.

The destination subdirectories must be writable. Create them first if needed:

```sh
mkdir -p /mnt/connections/data/{activities/content,blogs/upload,dogear/favorite,files/upload,forums/content,wikis/upload}
```

## Verify the copy

Review the logs, then run the configurable script with `--dry-run` again:

```sh
./rsync_shared_dir_options.sh \
  --source-dir /mnt/connections-old/data \
  --target-dir /mnt/connections/data \
  --dry-run
```

The dry run should report no files that need transfer. Keep the source mounted read-only until you finish the copy and verification.
