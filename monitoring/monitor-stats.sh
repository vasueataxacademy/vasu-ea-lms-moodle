#!/bin/bash

# Get script directory and create logs directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/logs"

# Function to log system stats
log_stats() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log Docker container stats in CSV format for easy analysis
    echo "[$timestamp] Docker Container Stats:" >> "$SCRIPT_DIR/logs/container-stats.log"
    docker stats --no-stream --format "{{.Container}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" >> "$SCRIPT_DIR/logs/container-stats.log"
    echo "" >> "$SCRIPT_DIR/logs/container-stats.log"
    
    # Log system stats
    echo "[$timestamp] System Stats:" >> "$SCRIPT_DIR/logs/system-stats.log"
    echo "CPU Usage:" >> "$SCRIPT_DIR/logs/system-stats.log"
    
    # Cross-platform CPU usage
    if command -v top >/dev/null 2>&1; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            top -l 1 | grep "CPU usage" >> "$SCRIPT_DIR/logs/system-stats.log" 2>/dev/null || echo "CPU info unavailable" >> "$SCRIPT_DIR/logs/system-stats.log"
        else
            # Linux
            top -bn1 | grep "Cpu(s)" >> "$SCRIPT_DIR/logs/system-stats.log" 2>/dev/null || echo "CPU info unavailable" >> "$SCRIPT_DIR/logs/system-stats.log"
        fi
    else
        echo "top command not available" >> "$SCRIPT_DIR/logs/system-stats.log"
    fi
    
    echo "Memory Usage:" >> "$SCRIPT_DIR/logs/system-stats.log"
    
    # Cross-platform memory usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        vm_stat | head -5 >> "$SCRIPT_DIR/logs/system-stats.log" 2>/dev/null || echo "Memory info unavailable" >> "$SCRIPT_DIR/logs/system-stats.log"
    else
        # Linux
        free -h >> "$SCRIPT_DIR/logs/system-stats.log" 2>/dev/null || echo "Memory info unavailable" >> "$SCRIPT_DIR/logs/system-stats.log"
    fi
    
    echo "Disk Usage:" >> "$SCRIPT_DIR/logs/system-stats.log"
    df -h / >> "$SCRIPT_DIR/logs/system-stats.log"
    echo "" >> "$SCRIPT_DIR/logs/system-stats.log"
    
    # Create daily summary
    date_only=$(date '+%Y-%m-%d')
    summary_file="$SCRIPT_DIR/logs/daily-summary-${date_only}.log"
    
    if [[ ! -f "$summary_file" ]]; then
        echo "Date,Time,Moodle_CPU,Moodle_Memory,MariaDB_CPU,MariaDB_Memory,Redis_CPU,Redis_Memory,Nginx_CPU,Nginx_Memory" > "$summary_file"
    fi
    
    # Extract key metrics for CSV summary
    time_only=$(date '+%H:%M:%S')
    moodle_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" moodle 2>/dev/null || echo "0%,0%")
    mariadb_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" mariadb 2>/dev/null || echo "0%,0%")
    redis_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" redis 2>/dev/null || echo "0%,0%")
    nginx_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" nginx 2>/dev/null || echo "0%,0%")
    
    echo "${date_only},${time_only},${moodle_stats},${mariadb_stats},${redis_stats},${nginx_stats}" >> "$summary_file"
}

# Function to show recent stats
show_recent() {
    echo "=== Recent Container Stats (Last 10 entries) ==="
    tail -20 "$SCRIPT_DIR/logs/container-stats.log" | grep -A 5 "Docker Container Stats"
    
    echo ""
    echo "=== Today's Summary ==="
    today=$(date '+%Y-%m-%d')
    if [[ -f "$SCRIPT_DIR/logs/daily-summary-${today}.log" ]]; then
        tail -10 "$SCRIPT_DIR/logs/daily-summary-${today}.log"
    else
        echo "No data for today yet"
    fi
}

# Function to analyze trends
analyze_trends() {
    echo "=== Resource Usage Analysis ==="
    
    # Find highest CPU usage
    echo "Highest CPU usage containers:"
    grep -h "," "$SCRIPT_DIR/logs/daily-summary-"*.log 2>/dev/null | sort -t',' -k3 -nr | head -5
    
    echo ""
    echo "Average usage over last 24 hours:"
    today=$(date '+%Y-%m-%d')
    yesterday=$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d '1 day ago' '+%Y-%m-%d')
    
    for file in "$SCRIPT_DIR/logs/daily-summary-${today}.log" "$SCRIPT_DIR/logs/daily-summary-${yesterday}.log"; do
        if [[ -f "$file" ]]; then
            echo "File: $file"
            awk -F',' 'NR>1 {cpu+=$3; mem+=$4; count++} END {if(count>0) printf "Moodle Avg: CPU=%.1f%%, Memory=%.1f%%\n", cpu/count, mem/count}' "$file"
        fi
    done
}

# Function to cleanup old data (older than 2 weeks)
cleanup_old_data() {
    echo "=== Cleaning up data older than 2 weeks ==="
    
    # Calculate cutoff date (2 weeks ago)
    cutoff_date=$(date -v-14d '+%Y-%m-%d' 2>/dev/null || date -d '14 days ago' '+%Y-%m-%d')
    cutoff_timestamp=$(date -j -f '%Y-%m-%d' "$cutoff_date" '+%s' 2>/dev/null || date -d "$cutoff_date" '+%s')
    
    deleted_count=0
    
    # Clean up daily summary files
    for file in "$SCRIPT_DIR/logs/daily-summary-"*.log; do
        if [[ -f "$file" ]]; then
            # Extract date from filename
            file_date=$(echo "$file" | sed 's/.*daily-summary-\([0-9-]*\)\.log/\1/')
            if [[ "$file_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                file_timestamp=$(date -j -f '%Y-%m-%d' "$file_date" '+%s' 2>/dev/null || date -d "$file_date" '+%s' 2>/dev/null)
                if [[ $file_timestamp -lt $cutoff_timestamp ]]; then
                    echo "Deleting old summary file: $file"
                    rm "$file"
                    ((deleted_count++))
                fi
            fi
        fi
    done
    
    # Clean up old entries from main log files
    temp_container_log=$(mktemp)
    temp_system_log=$(mktemp)
    
    # Clean container stats log
    if [[ -f "$SCRIPT_DIR/logs/container-stats.log" ]]; then
        awk -v cutoff="$cutoff_date" '
        /^\[/ {
            # Extract date from timestamp [YYYY-MM-DD HH:MM:SS]
            match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, arr)
            if (arr[1] >= cutoff) {
                print $0
                keep_section = 1
            } else {
                keep_section = 0
            }
            next
        }
        keep_section { print $0 }
        ' "$SCRIPT_DIR/logs/container-stats.log" > "$temp_container_log"
        
        if [[ -s "$temp_container_log" ]]; then
            mv "$temp_container_log" "$SCRIPT_DIR/logs/container-stats.log"
            echo "Cleaned old entries from container-stats.log"
        fi
    fi
    
    # Clean system stats log
    if [[ -f "$SCRIPT_DIR/logs/system-stats.log" ]]; then
        awk -v cutoff="$cutoff_date" '
        /^\[/ {
            # Extract date from timestamp [YYYY-MM-DD HH:MM:SS]
            match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, arr)
            if (arr[1] >= cutoff) {
                print $0
                keep_section = 1
            } else {
                keep_section = 0
            }
            next
        }
        keep_section { print $0 }
        ' "$SCRIPT_DIR/logs/system-stats.log" > "$temp_system_log"
        
        if [[ -s "$temp_system_log" ]]; then
            mv "$temp_system_log" "$SCRIPT_DIR/logs/system-stats.log"
            echo "Cleaned old entries from system-stats.log"
        fi
    fi
    
    # Clean up temp files
    rm -f "$temp_container_log" "$temp_system_log"
    
    echo "Cleanup completed. Deleted $deleted_count daily summary files and cleaned main log files."
    echo "Data older than $cutoff_date has been removed."
}

# Main script logic
case "${1:-run}" in
    "run")
        log_stats
        echo "Stats logged to monitoring/logs/ directory"
        echo ""
        echo "Available commands:"
        echo "  ./monitor-stats.sh show    - Show recent stats"
        echo "  ./monitor-stats.sh analyze - Analyze trends"
        echo "  ./monitor-stats.sh cleanup - Delete data older than 2 weeks"
        echo "  ./monitor-stats.sh setup   - Setup automated logging"
        ;;
    "show")
        show_recent
        ;;
    "analyze")
        analyze_trends
        ;;
    "cleanup")
        cleanup_old_data
        ;;
    "setup")
        echo "Setting up automated logging..."
        echo "Add this line to your crontab (crontab -e):"
        echo "*/5 * * * * $(pwd)/monitor-stats.sh run"
        echo ""
        echo "For automated cleanup, also add:"
        echo "0 2 * * 0 $(pwd)/monitor-stats.sh cleanup"
        echo ""
        echo "Or run this command to add both automatically:"
        echo "(crontab -l 2>/dev/null; echo \"*/5 * * * * $(pwd)/monitor-stats.sh run\"; echo \"0 2 * * 0 $(pwd)/monitor-stats.sh cleanup\") | crontab -"
        ;;
    *)
        echo "Usage: $0 [run|show|analyze|cleanup|setup]"
        ;;
esac