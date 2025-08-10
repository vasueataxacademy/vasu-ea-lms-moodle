#!/bin/bash

# Get script directory and create logs directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/logs"

# Function to check Docker status
check_docker_status() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker command not found"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker daemon not running or not accessible"
        return 1
    fi
    
    running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
    total_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l)
    
    echo "✅ Docker is running ($running_containers/$total_containers containers active)"
    return 0
}

# Function to log system stats
log_stats() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log Docker container stats in CSV format for easy analysis
    echo "[$timestamp] Docker Container Stats:" >> "$SCRIPT_DIR/logs/container-stats.log"
    
    # Check if Docker is running and accessible
    if ! docker info >/dev/null 2>&1; then
        echo "Docker daemon not running or not accessible" >> "$SCRIPT_DIR/logs/container-stats.log"
        echo "" >> "$SCRIPT_DIR/logs/container-stats.log"
    else
        # Check if any containers are running
        running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
        if [[ -z "$running_containers" ]]; then
            echo "No Docker containers currently running" >> "$SCRIPT_DIR/logs/container-stats.log"
            echo "" >> "$SCRIPT_DIR/logs/container-stats.log"
        else
            # Get stats for running containers
            docker stats --no-stream --format "{{.Container}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" >> "$SCRIPT_DIR/logs/container-stats.log" 2>/dev/null || echo "Failed to collect container stats" >> "$SCRIPT_DIR/logs/container-stats.log"
            echo "" >> "$SCRIPT_DIR/logs/container-stats.log"
        fi
    fi
    
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
    
    # Check if Docker is accessible before collecting container stats
    if docker info >/dev/null 2>&1; then
        # Get stats for each container, with fallback for missing containers
        moodle_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" moodle 2>/dev/null || echo "N/A,N/A")
        mariadb_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" mariadb 2>/dev/null || echo "N/A,N/A")
        redis_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" redis 2>/dev/null || echo "N/A,N/A")
        nginx_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" nginx 2>/dev/null || echo "N/A,N/A")
    else
        # Docker not accessible - mark all as unavailable
        moodle_stats="DOCKER_DOWN,DOCKER_DOWN"
        mariadb_stats="DOCKER_DOWN,DOCKER_DOWN"
        redis_stats="DOCKER_DOWN,DOCKER_DOWN"
        nginx_stats="DOCKER_DOWN,DOCKER_DOWN"
    fi
    
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
        echo "=== Monitoring Status ==="
        check_docker_status
        echo ""
        
        log_stats
        echo "📊 Stats logged to monitoring/logs/ directory"
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
        echo ""
        
        # Check if crontab is available
        if command -v crontab >/dev/null 2>&1; then
            echo "✅ Crontab is available. Add these lines to your crontab (crontab -e):"
            echo "*/5 * * * * $(pwd)/monitoring/monitor-stats.sh run"
            echo "0 2 * * 0 $(pwd)/monitoring/monitor-stats.sh cleanup"
            echo ""
            echo "Or run this command to add both automatically:"
            echo "(crontab -l 2>/dev/null; echo \"*/5 * * * * $(pwd)/monitoring/monitor-stats.sh run\"; echo \"0 2 * * 0 $(pwd)/monitoring/monitor-stats.sh cleanup\") | crontab -"
        else
            echo "❌ Crontab not available. Alternative setup options:"
            echo ""
            echo "1. Install cron (recommended):"
            echo "   Run: ./monitoring/install-cron.sh"
            echo ""
            echo "2. Use systemd timer (modern Linux alternative):"
            echo "   Run: ./monitoring/monitor-stats.sh systemd-setup"
            echo ""
            echo "3. Simple monitoring service:"
            echo "   Run: ./monitoring/start-monitoring.sh start"
            echo "   (Managed background service with start/stop/status)"
            echo ""
            echo "4. Manual background loop:"
            echo "   Run: ./monitoring/monitor-stats.sh loop &"
            echo "   (Simple continuous loop)"
        fi
        ;;
    "systemd-setup")
        echo "Setting up systemd timer for monitoring..."
        echo ""
        echo "1. Create systemd service file:"
        echo "sudo tee /etc/systemd/system/moodle-monitor.service > /dev/null <<EOF"
        echo "[Unit]"
        echo "Description=Moodle Resource Monitor"
        echo "After=docker.service"
        echo ""
        echo "[Service]"
        echo "Type=oneshot"
        echo "ExecStart=$(pwd)/monitoring/monitor-stats.sh run"
        echo "User=$(whoami)"
        echo "WorkingDirectory=$(pwd)"
        echo "EOF"
        echo ""
        echo "2. Create systemd timer file:"
        echo "sudo tee /etc/systemd/system/moodle-monitor.timer > /dev/null <<EOF"
        echo "[Unit]"
        echo "Description=Run Moodle Monitor every 5 minutes"
        echo "Requires=moodle-monitor.service"
        echo ""
        echo "[Timer]"
        echo "OnCalendar=*:0/5"
        echo "Persistent=true"
        echo ""
        echo "[Install]"
        echo "WantedBy=timers.target"
        echo "EOF"
        echo ""
        echo "3. Enable and start the timer:"
        echo "sudo systemctl daemon-reload"
        echo "sudo systemctl enable moodle-monitor.timer"
        echo "sudo systemctl start moodle-monitor.timer"
        echo ""
        echo "4. Check status:"
        echo "sudo systemctl status moodle-monitor.timer"
        ;;
    "status")
        echo "=== System Monitoring Status ==="
        echo ""
        check_docker_status
        echo ""
        
        echo "📁 Log Files:"
        if [[ -f "$SCRIPT_DIR/logs/container-stats.log" ]]; then
            echo "  ✅ Container stats: $(wc -l < "$SCRIPT_DIR/logs/container-stats.log") lines"
        else
            echo "  ❌ No container stats log found"
        fi
        
        if [[ -f "$SCRIPT_DIR/logs/system-stats.log" ]]; then
            echo "  ✅ System stats: $(wc -l < "$SCRIPT_DIR/logs/system-stats.log") lines"
        else
            echo "  ❌ No system stats log found"
        fi
        
        echo ""
        echo "📊 Daily Summaries:"
        summary_count=$(ls "$SCRIPT_DIR/logs/daily-summary-"*.log 2>/dev/null | wc -l)
        if [[ $summary_count -gt 0 ]]; then
            echo "  ✅ $summary_count daily summary files found"
            echo "  📅 Latest: $(ls -t "$SCRIPT_DIR/logs/daily-summary-"*.log 2>/dev/null | head -1 | xargs basename)"
        else
            echo "  ❌ No daily summary files found"
        fi
        ;;
    "loop")
        echo "Starting continuous monitoring loop (every 5 minutes)..."
        echo "Press Ctrl+C to stop, or run in background with: $0 loop &"
        echo ""
        while true; do
            echo "=== $(date) ==="
            check_docker_status
            log_stats
            echo "📊 Stats logged. Next run in 5 minutes..."
            echo ""
            sleep 300  # 5 minutes
        done
        ;;
    *)
        echo "Usage: $0 [run|show|analyze|cleanup|setup|systemd-setup|status|loop]"
        echo ""
        echo "Commands:"
        echo "  run           - Log current stats once"
        echo "  show          - Show recent stats"
        echo "  analyze       - Analyze trends"
        echo "  cleanup       - Delete data older than 2 weeks"
        echo "  setup         - Show automated setup options"
        echo "  systemd-setup - Generate systemd timer setup commands"
        echo "  status        - Check monitoring and Docker status"
        echo "  loop          - Run continuous monitoring loop"
        ;;
esac