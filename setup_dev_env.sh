#!/usr/bin/env bash
# Requires: root privileges, getfacl/setfacl (acl package)

set -euo pipefail

# ─── constants ────────────────────────────────────────────────────────────────
DEV_GROUP="dev"
SUDOERS_FILE="/etc/sudoers.d/dev_nopasswd"
LOG_FILE="/var/log/setup_dev_env.log"
MIN_UID=1000   # non-system users have UID >= 1000 on Linux

# ─── logging ──────────────────────────────────────────────────────────────────
log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] %s\n' "$ts" "$*" | tee -a "$LOG_FILE"
}

# ─── root check ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run this script as root (sudo $0 $*)" >&2
    exit 1
fi

# ─── argument parsing ─────────────────────────────────────────────────────────
BASE_DIR=""
while getopts ":d:" opt; do
    case $opt in
        d) BASE_DIR="$OPTARG" ;;
        :) echo "ERROR: option -$OPTARG requires an argument." >&2; exit 1 ;;
        \?) echo "ERROR: unknown option -$OPTARG." >&2; exit 1 ;;
    esac
done

if [[ -z "$BASE_DIR" ]]; then
    read -rp "Enter base directory for workdirs: " BASE_DIR
fi

# strip trailing slash for consistency
BASE_DIR="${BASE_DIR%/}"

if [[ -z "$BASE_DIR" ]]; then
    echo "ERROR: base directory cannot be empty." >&2
    exit 1
fi

log "=== setup_dev_env.sh started ==="
log "Base directory: $BASE_DIR"

# ─── 1. create dev group ──────────────────────────────────────────────────────
if getent group "$DEV_GROUP" &>/dev/null; then
    log "Group '$DEV_GROUP' already exists — skipping creation."
else
    groupadd "$DEV_GROUP"
    log "Group '$DEV_GROUP' created."
fi

# ─── 2. collect non-system users ─────────────────────────────────────────────
mapfile -t NON_SYSTEM_USERS < <(
    awk -F: -v min="$MIN_UID" '$3 >= min && $3 < 65534 { print $1 }' /etc/passwd
)

if [[ ${#NON_SYSTEM_USERS[@]} -eq 0 ]]; then
    log "WARNING: no non-system users found (UID >= $MIN_UID)."
fi

# ─── 3. add non-system users to dev group ────────────────────────────────────
for user in "${NON_SYSTEM_USERS[@]}"; do
    if id -nG "$user" | tr ' ' '\n' | grep -qx "$DEV_GROUP"; then
        log "User '$user' is already in group '$DEV_GROUP' — skipping."
    else
        usermod -aG "$DEV_GROUP" "$user"
        log "User '$user' added to group '$DEV_GROUP'."
    fi
done

# ─── 4. sudo without password for dev group ───────────────────────────────────
SUDOERS_RULE="%${DEV_GROUP} ALL=(ALL) NOPASSWD: ALL"
if [[ -f "$SUDOERS_FILE" ]] && grep -qF "$SUDOERS_RULE" "$SUDOERS_FILE"; then
    log "Sudoers rule for '$DEV_GROUP' already present — skipping."
else
    echo "$SUDOERS_RULE" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    # validate to avoid locking out sudo
    if visudo -cf "$SUDOERS_FILE"; then
        log "Sudoers rule written: $SUDOERS_FILE"
    else
        rm -f "$SUDOERS_FILE"
        log "ERROR: invalid sudoers syntax — rule removed for safety."
        exit 1
    fi
fi

# ─── 5. create base directory if needed ──────────────────────────────────────
if [[ ! -d "$BASE_DIR" ]]; then
    mkdir -p "$BASE_DIR"
    log "Base directory '$BASE_DIR' created."
fi

# ─── 6. check ACL support ─────────────────────────────────────────────────────
if ! command -v setfacl &>/dev/null; then
    log "WARNING: setfacl not found. Install 'acl' package to enable ACL support."
    USE_ACL=false
else
    USE_ACL=true
fi

# ─── 7. create workdirs and set permissions ───────────────────────────────────
for user in "${NON_SYSTEM_USERS[@]}"; do
    user_group=$(id -gn "$user")
    workdir="${BASE_DIR}/${user}_workdir"

    if [[ ! -d "$workdir" ]]; then
        mkdir -p "$workdir"
        log "Directory '$workdir' created."
    else
        log "Directory '$workdir' already exists — updating permissions."
    fi

    # owner = user, group = user's primary group, mode = 660
    chown "${user}:${user_group}" "$workdir"
    chmod 660 "$workdir"
    log "  permissions: 660  owner: ${user}  group: ${user_group}"

    # ACL: read access for dev group
    if $USE_ACL; then
        setfacl -m "g:${DEV_GROUP}:r-x" "$workdir"
        log "  ACL: group '${DEV_GROUP}' granted read+execute on '$workdir'."
    else
        log "  ACL skipped (setfacl unavailable)."
    fi
done

log "=== setup_dev_env.sh finished successfully ==="
log "Log file: $LOG_FILE"
