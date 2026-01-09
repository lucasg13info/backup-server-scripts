#!/bin/bash
# ==========================================
# SERVER BACKUP SCRIPT
# (POSTGRES + SYSTEM + GOOGLE DRIVE + EMAIL)
# ==========================================

set -euo pipefail

# ------------------------------
# CONFIGURATION
# ------------------------------
CURRENT_DIR=$(pwd)
BASE_DIR="$CURRENT_DIR"
BACKUP_DIR="$BASE_DIR/backup"
DATE=$(date +%F)
BACKUP_FILE="$BACKUP_DIR/backup-$DATE.tar.gz"
LOG_FILE="$BACKUP_DIR/backup-$DATE.log"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BASE_DIR" "$BACKUP_DIR"

# ------------------------------
# POSTGRES CONFIG
# ------------------------------
POSTGRES_CONTAINER="postgres-blog-Lucas"
POSTGRES_USER="amigoscode"
POSTGRES_DB="bloglucas"
POSTGRES_DUMP_FILE="$BACKUP_DIR/postgres-$POSTGRES_DB.dump"

# ------------------------------
# SYSTEM CONFIG
# ------------------------------
FOLDERS_TO_BACKUP=("/etc" "/srv" "/var/www" "/home")
PACKAGES_FILE="$BACKUP_DIR/packages.list"

# ------------------------------
# GOOGLE DRIVE
# ------------------------------
GDRIVE_REMOTE="gdrive-crypt"
GDRIVE_FOLDER="server-backups"

# ------------------------------
# RETENTION
# ------------------------------
RETENTION_DAYS=7

# ------------------------------
# EMAIL
# ------------------------------
EMAIL="lucccasestefano1@gmail.com"
EMAIL_SUBJECT_SUCCESS="✅ Server Backup SUCCESS - $DATE - $(hostname)"
EMAIL_SUBJECT_ERROR="❌ Server Backup ERROR - $DATE - $(hostname)"

# ------------------------------
# LOG REDIRECTION
# ------------------------------
exec > >(tee -a "$LOG_FILE") 2>&1

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo "=========================================="
echo "Backup started at $START_TIME"
echo "Backup directory: $BACKUP_DIR"
echo "=========================================="

# ------------------------------
# FUNCTIONS
# ------------------------------

send_email_mime() {
    local subject="$1"
    local body="$2"
    local attachment="$3"

    TMP_EMAIL=$(mktemp /tmp/email.XXXXXX)
    {
        echo "From: servernotifications@lucasrestefano.blog"
        echo "To: $EMAIL"
        echo "Subject: $subject"
        echo "MIME-Version: 1.0"
        echo "Content-Type: multipart/mixed; boundary=\"BOUNDARY\""
        echo
        echo "--BOUNDARY"
        echo "Content-Type: text/plain; charset=utf-8"
        echo
        echo "$body"
        echo
        if [[ -f "$attachment" ]]; then
            echo "--BOUNDARY"
            echo "Content-Type: text/plain; name=\"$(basename "$attachment")\""
            echo "Content-Disposition: attachment; filename=\"$(basename "$attachment")\""
            echo "Content-Transfer-Encoding: base64"
            echo
            base64 "$attachment"
        fi
        echo "--BOUNDARY--"
    } > "$TMP_EMAIL"

    msmtp -a hostinger "$EMAIL" < "$TMP_EMAIL"
    rm -f "$TMP_EMAIL"
}

send_error() {
    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[ERROR] $1"
    echo "Backup failed at $END_TIME"

    EMAIL_BODY="Backup FAILED ❌

Start time: $START_TIME
End time: $END_TIME
Hostname: $(hostname)
Error details: $1

Please see the attached log file for full details."

    send_email_mime "$EMAIL_SUBJECT_ERROR" "$EMAIL_BODY" "$LOG_FILE"
    exit 1
}

send_success() {
    END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    FILE_SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
    NUM_FILES=$(tar -tf "$BACKUP_FILE" | wc -l)

    EMAIL_BODY="Backup completed successfully ✅

Start time: $START_TIME
End time: $END_TIME
Hostname: $(hostname)
Backup directory: $BACKUP_DIR
Backup file: $(basename "$BACKUP_FILE")
File size: $FILE_SIZE
Number of files in backup: $NUM_FILES
Retention policy: $RETENTION_DAYS days

Database dumped: $POSTGRES_DB
System folders: ${FOLDERS_TO_BACKUP[*]}

Please see the attached log file for full details."

    send_email_mime "$EMAIL_SUBJECT_SUCCESS" "$EMAIL_BODY" "$LOG_FILE"
}

# ------------------------------
# 1️⃣ POSTGRES DATABASE DUMP
# ------------------------------
echo "[INFO] Checking Postgres container status..."
if ! docker ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
    send_error "Postgres container '$POSTGRES_CONTAINER' is not running."
fi

echo "[INFO] Creating Postgres dump for database '$POSTGRES_DB'..."
docker exec "$POSTGRES_CONTAINER" \
pg_dump -U "$POSTGRES_USER" -F c -b -v "$POSTGRES_DB" \
> "$POSTGRES_DUMP_FILE" || send_error "Postgres dump failed."

# ------------------------------
# 2️⃣ SAVE INSTALLED PACKAGES
# ------------------------------
echo "[INFO] Saving list of installed Debian packages..."
dpkg --get-selections > "$PACKAGES_FILE"

# ------------------------------
# 3️⃣ CREATE COMPRESSED ARCHIVE
# ------------------------------
echo "[INFO] Creating compressed backup archive..."
tar -czf "$BACKUP_FILE" \
"${FOLDERS_TO_BACKUP[@]}" \
"$POSTGRES_DUMP_FILE" \
"$PACKAGES_FILE" \
|| send_error "Failed to create backup archive."

# ------------------------------
# 4️⃣ UPLOAD TO GOOGLE DRIVE
# ------------------------------
echo "[INFO] Uploading backup to Google Drive (encrypted)..."
rclone copy "$BACKUP_FILE" "$GDRIVE_REMOTE:$GDRIVE_FOLDER" --progress \
|| send_error "Failed to upload backup to Google Drive."

# ------------------------------
# 5️⃣ REMOTE RETENTION POLICY
# ------------------------------
echo "[INFO] Applying retention policy on Google Drive..."
rclone delete "$GDRIVE_REMOTE:$GDRIVE_FOLDER" --min-age "${RETENTION_DAYS}d"

# ------------------------------
# 6️⃣ LOCAL CLEANUP
# ------------------------------
echo "[INFO] Cleaning up local backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete

# ------------------------------
# 7️⃣ SUCCESS EMAIL
# ------------------------------
send_success
