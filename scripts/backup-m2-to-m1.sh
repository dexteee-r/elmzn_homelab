#!/bin/bash

################################################################################
# BACKUP SCRIPT - Machine #2 (INTRANET) → Machine #1 (EXTRANET)
# Version: 1.0
# Description: Automated backup using Restic (encrypted, incremental)
################################################################################

set -euo pipefail  # Exit on error, undefined var, pipe failure

# =============================================================================
# CONFIGURATION
# =============================================================================

# Load environment variables
if [ -f "/opt/intranet/.env" ]; then
    source /opt/intranet/.env
else
    echo "❌ Error: .env file not found at /opt/intranet/.env"
    exit 1
fi

# Backup paths
PHOTOS_PATH="/mnt/photos"
FILES_PATH="/mnt/files"
CONFIGS_PATH="/opt/intranet"
POSTGRES_BACKUP="/tmp/postgres-backup.sql"

# Restic configuration
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-sftp:root@<IP_VM_EXTRANET>:/mnt/backups-m2}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"

# Logging
LOG_FILE="/var/log/backup-m2-to-m1.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Notification (optionnel - webhook Discord/Slack)
# WEBHOOK_URL=""

# =============================================================================
# FUNCTIONS
# =============================================================================

log() {
    echo "[$DATE] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$DATE] ❌ ERROR: $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[$DATE] ✅ SUCCESS: $1" | tee -a "$LOG_FILE"
}

check_restic() {
    if ! command -v restic &> /dev/null; then
        log_error "Restic not installed. Install with: apt install restic"
        exit 1
    fi
}

check_repository() {
    if ! restic snapshots &> /dev/null; then
        log "⚠️  Repository not initialized. Initializing..."
        restic init
    fi
}

backup_postgres() {
    log "📦 Backing up PostgreSQL databases..."
    
    # Dump all databases
    docker exec postgres pg_dumpall -U postgres > "$POSTGRES_BACKUP"
    
    if [ $? -eq 0 ]; then
        log_success "PostgreSQL dump created: $POSTGRES_BACKUP"
        
        # Backup to Restic
        restic backup "$POSTGRES_BACKUP" --tag database --tag postgres
        
        # Remove temp file
        rm -f "$POSTGRES_BACKUP"
    else
        log_error "PostgreSQL dump failed"
        return 1
    fi
}

backup_configs() {
    log "⚙️  Backing up Docker configs..."
    
    restic backup "$CONFIGS_PATH" \
        --tag configs \
        --tag docker \
        --exclude='*.log' \
        --exclude='*/data/*' \
        --exclude='*/cache/*'
    
    if [ $? -eq 0 ]; then
        log_success "Docker configs backed up"
    else
        log_error "Docker configs backup failed"
        return 1
    fi
}

backup_photos() {
    log "📸 Backing up photos (Immich)..."
    
    # Check if photos path exists and has content
    if [ ! -d "$PHOTOS_PATH" ] || [ -z "$(ls -A $PHOTOS_PATH)" ]; then
        log "⚠️  Photos path empty or not mounted, skipping..."
        return 0
    fi
    
    restic backup "$PHOTOS_PATH" \
        --tag photos \
        --tag immich \
        --exclude='*.tmp' \
        --exclude='*/thumbs/*'
    
    if [ $? -eq 0 ]; then
        log_success "Photos backed up"
    else
        log_error "Photos backup failed"
        return 1
    fi
}

backup_files() {
    log "📁 Backing up files (Nextcloud)..."
    
    # Check if files path exists and has content
    if [ ! -d "$FILES_PATH" ] || [ -z "$(ls -A $FILES_PATH)" ]; then
        log "⚠️  Files path empty or not mounted, skipping..."
        return 0
    fi
    
    restic backup "$FILES_PATH" \
        --tag files \
        --tag nextcloud \
        --exclude='*/cache/*' \
        --exclude='*/tmp/*'
    
    if [ $? -eq 0 ]; then
        log_success "Files backed up"
    else
        log_error "Files backup failed"
        return 1
    fi
}

prune_snapshots() {
    log "🗑️  Pruning old snapshots..."
    
    restic forget \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 6 \
        --prune
    
    if [ $? -eq 0 ]; then
        log_success "Old snapshots pruned"
    else
        log_error "Pruning failed"
        return 1
    fi
}

check_integrity() {
    log "🔍 Checking repository integrity..."
    
    # Run check (with 10% probability to avoid overhead)
    if [ $((RANDOM % 10)) -eq 0 ]; then
        restic check --read-data-subset=5%
        
        if [ $? -eq 0 ]; then
            log_success "Repository integrity OK"
        else
            log_error "Repository integrity check failed!"
            return 1
        fi
    else
        log "Skipping integrity check (random 10% chance)"
    fi
}

show_stats() {
    log "📊 Backup statistics:"
    
    # Show latest snapshot
    restic snapshots --last
    
    # Show repository stats
    restic stats
}

send_notification() {
    local status=$1
    local message=$2
    
    if [ -n "${WEBHOOK_URL:-}" ]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"🏠 Media Server Backup\n**Status:** $status\n**Message:** $message\"}"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "🚀 Starting backup: Machine #2 → Machine #1"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Pre-checks
    check_restic
    check_repository
    
    # Track errors
    ERRORS=0
    
    # Execute backups
    backup_postgres || ((ERRORS++))
    backup_configs || ((ERRORS++))
    backup_photos || ((ERRORS++))
    backup_files || ((ERRORS++))
    
    # Maintenance
    prune_snapshots || ((ERRORS++))
    check_integrity || ((ERRORS++))
    
    # Show stats
    show_stats
    
    # Final status
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ $ERRORS -eq 0 ]; then
        log_success "✅ Backup completed successfully!"
        send_notification "SUCCESS" "All backups completed without errors"
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 0
    else
        log_error "❌ Backup completed with $ERRORS error(s)"
        send_notification "WARNING" "Backup completed with $ERRORS error(s)"
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 1
    fi
}

# Run main function
main "$@"

# =============================================================================
# USAGE
# =============================================================================
#
# Manual execution:
#   sudo ./backup-m2-to-m1.sh
#
# Add to crontab (daily at 2 AM):
#   sudo crontab -e
#   0 2 * * * /root/scripts/backup-m2-to-m1.sh >> /var/log/backup-m2-to-m1.log 2>&1
#
# List snapshots:
#   restic snapshots
#
# Restore specific snapshot:
#   restic restore SNAPSHOT_ID --target /restore
#
# Restore latest photos:
#   restic restore latest --target /restore --tag photos
#
# Restore PostgreSQL:
#   restic restore latest --target /tmp --tag database
#   docker exec -i postgres psql -U postgres < /tmp/postgres-backup.sql
#
# =============================================================================
