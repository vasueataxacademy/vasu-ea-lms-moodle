#!/bin/bash

# Simple log analysis tools
# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_usage_graph() {
    echo "=== CPU Usage Over Time (Last 24 Hours) ==="
    echo "Time     | Moodle | MariaDB | Redis | Nginx"
    echo "---------|--------|---------|-------|-------"
    
    today=$(date '+%Y-%m-%d')
    if [[ -f "$SCRIPT_DIR/logs/daily-summary-${today}.log" ]]; then
        tail -20 "$SCRIPT_DIR/logs/daily-summary-${today}.log" | awk -F',' '
        NR>1 {
            printf "%-8s | %-6s | %-7s | %-5s | %-5s\n", 
            $2, $3, $5, $7, $9
        }'
    fi
}

show_memory_alerts() {
    echo "=== Memory Usage Alerts (>80%) ==="
    
    for file in "$SCRIPT_DIR/logs/daily-summary-"*.log; do
        if [[ -f "$file" ]]; then
            awk -F',' '
            NR>1 {
                if ($4+0 > 80) printf "ALERT: %s %s - Moodle Memory: %s\n", $1, $2, $4
                if ($6+0 > 80) printf "ALERT: %s %s - MariaDB Memory: %s\n", $1, $2, $6
                if ($8+0 > 80) printf "ALERT: %s %s - Redis Memory: %s\n", $1, $2, $8
            }' "$file"
        fi
    done
}

show_peak_usage() {
    echo "=== Peak Usage Times ==="
    
    for file in "$SCRIPT_DIR/logs/daily-summary-"*.log; do
        if [[ -f "$file" ]]; then
            echo "File: $(basename $file)"
            echo "Peak CPU usage:"
            awk -F',' 'NR>1 {print $2, $3}' "$file" | sort -k2 -nr | head -3
            echo "Peak Memory usage:"
            awk -F',' 'NR>1 {print $2, $4}' "$file" | sort -k2 -nr | head -3
            echo ""
        fi
    done
}

generate_report() {
    echo "=== Daily Resource Report ===" > "$SCRIPT_DIR/logs/daily-report.txt"
    echo "Generated: $(date)" >> "$SCRIPT_DIR/logs/daily-report.txt"
    echo "" >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    show_usage_graph >> "$SCRIPT_DIR/logs/daily-report.txt"
    echo "" >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    show_memory_alerts >> "$SCRIPT_DIR/logs/daily-report.txt"
    echo "" >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    show_peak_usage >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    echo "Report saved to monitoring/logs/daily-report.txt"
}

case "${1:-graph}" in
    "graph")
        show_usage_graph
        ;;
    "alerts")
        show_memory_alerts
        ;;
    "peaks")
        show_peak_usage
        ;;
    "report")
        generate_report
        ;;
    *)
        echo "Usage: $0 [graph|alerts|peaks|report]"
        echo ""
        echo "Commands:"
        echo "  graph  - Show CPU usage over time"
        echo "  alerts - Show memory usage alerts"
        echo "  peaks  - Show peak usage times"
        echo "  report - Generate full daily report"
        ;;
esac