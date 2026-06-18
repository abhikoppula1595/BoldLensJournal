#!/bin/bash

##############################################################################
# Script: check_disk_usage.sh
# Description: Check disk usage and alert if above 80% threshold
# Usage: ./check_disk_usage.sh [optional_email]
##############################################################################

# Configuration
THRESHOLD=80
ALERT_EMAIL="${1:-}"  # Optional email for notifications

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

##############################################################################
# Function: Check disk usage for all mounted filesystems
##############################################################################
check_disk_usage() {
    echo "=================================================="
    echo "Disk Usage Report - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================================="
    
    local alert_triggered=0
    local alert_message=""
    
    # Get disk usage info using df command
    # -h: human-readable format
    # -x: exclude specified filesystem types
    df -h -x tmpfs -x devtmpfs -x udev | tail -n +2 | while read -r line; do
        # Parse the output
        filesystem=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        available=$(echo "$line" | awk '{print $4}')
        usage_percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        mount_point=$(echo "$line" | awk '{print $6}')
        
        # Color-code the output based on usage percentage
        if (( usage_percent >= THRESHOLD )); then
            printf "${RED}[ALERT]${NC} "
            alert_triggered=1
            alert_message="${alert_message}${filesystem}: ${usage_percent}% (${used}/${size})\n"
        elif (( usage_percent >= 70 )); then
            printf "${YELLOW}[WARN]${NC}  "
        else
            printf "${GREEN}[OK]${NC}    "
        fi
        
        printf "%-25s %6s / %-6s (%3d%%) - %s\n" \
            "$filesystem" "$used" "$size" "$usage_percent" "$mount_point"
    done
    
    echo "=================================================="
    
    return $alert_triggered
}

##############################################################################
# Function: Send email alert
##############################################################################
send_email_alert() {
    local alert_message="$1"
    local email="$2"
    
    if command -v mail &> /dev/null; then
        echo -e "$alert_message" | mail -s "DISK USAGE ALERT - High disk usage detected" "$email"
        echo "Alert email sent to: $email"
    elif command -v sendmail &> /dev/null; then
        {
            echo "Subject: DISK USAGE ALERT - High disk usage detected"
            echo "To: $email"
            echo ""
            echo -e "$alert_message"
        } | sendmail "$email"
        echo "Alert email sent to: $email"
    else
        echo "Warning: No email utility found (mail/sendmail). Cannot send alert."
        return 1
    fi
}

##############################################################################
# Function: Log alert to syslog
##############################################################################
log_alert() {
    local alert_message="$1"
    
    if command -v logger &> /dev/null; then
        logger -t disk_usage_check "ALERT: $alert_message"
    fi
}

##############################################################################
# Main execution
##############################################################################
main() {
    # Check disk usage
    check_disk_usage
    local exit_code=$?
    
    # If usage exceeds threshold
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo -e "${RED}WARNING: Disk usage exceeds ${THRESHOLD}% threshold!${NC}"
        echo ""
        
        # Send email if configured
        if [[ -n "$ALERT_EMAIL" ]]; then
            alert_msg="Disk usage alert - one or more filesystems exceed ${THRESHOLD}% capacity.\n\n"
            alert_msg="${alert_msg}$(df -h -x tmpfs -x devtmpfs -x udev | grep -E '^/')"
            send_email_alert "$alert_msg" "$ALERT_EMAIL"
        fi
        
        # Log to syslog
        log_alert "Disk usage exceeds ${THRESHOLD}% threshold"
        
        return 1
    else
        echo ""
        echo -e "${GREEN}All filesystems within acceptable limits.${NC}"
        return 0
    fi
}

# Run main function
main "$@"
