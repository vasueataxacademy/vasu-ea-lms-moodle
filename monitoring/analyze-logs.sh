#!/bin/bash

# Simple log analysis tools
# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_usage_graph() {
    echo "=== Resource Usage Over Time (Last 24 Hours) ==="
    echo ""
    echo "CPU Usage:"
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
    
    echo ""
    echo "Memory Usage:"
    echo "Time     | Moodle | MariaDB | Redis | Nginx"
    echo "---------|--------|---------|-------|-------"
    
    if [[ -f "$SCRIPT_DIR/logs/daily-summary-${today}.log" ]]; then
        tail -20 "$SCRIPT_DIR/logs/daily-summary-${today}.log" | awk -F',' '
        NR>1 {
            printf "%-8s | %-6s | %-7s | %-5s | %-5s\n", 
            $2, $4, $6, $8, $10
        }'
    fi
}

show_memory_alerts() {
    echo "=== Resource Usage Alerts ==="
    echo ""
    echo "🚨 High Memory Usage (>80%):"
    
    alert_count=0
    for file in "$SCRIPT_DIR/logs/daily-summary-"*.log; do
        if [[ -f "$file" ]]; then
            awk -F',' '
            NR>1 {
                if ($4+0 > 80) { printf "  ⚠️  %s %s - Moodle Memory: %s\n", $1, $2, $4; alert_found=1 }
                if ($6+0 > 80) { printf "  ⚠️  %s %s - MariaDB Memory: %s\n", $1, $2, $6; alert_found=1 }
                if ($8+0 > 80) { printf "  ⚠️  %s %s - Redis Memory: %s\n", $1, $2, $8; alert_found=1 }
                if ($10+0 > 80) { printf "  ⚠️  %s %s - Nginx Memory: %s\n", $1, $2, $10; alert_found=1 }
            }
            END { if (!alert_found) exit 1 }
            ' "$file" && alert_count=$((alert_count + 1))
        fi
    done
    
    if [[ $alert_count -eq 0 ]]; then
        echo "  ✅ No high memory usage alerts found"
    fi
    
    echo ""
    echo "🔥 High CPU Usage (>90%):"
    
    alert_count=0
    for file in "$SCRIPT_DIR/logs/daily-summary-"*.log; do
        if [[ -f "$file" ]]; then
            awk -F',' '
            NR>1 {
                if ($3+0 > 90) { printf "  ⚠️  %s %s - Moodle CPU: %s\n", $1, $2, $3; alert_found=1 }
                if ($5+0 > 90) { printf "  ⚠️  %s %s - MariaDB CPU: %s\n", $1, $2, $5; alert_found=1 }
                if ($7+0 > 90) { printf "  ⚠️  %s %s - Redis CPU: %s\n", $1, $2, $7; alert_found=1 }
                if ($9+0 > 90) { printf "  ⚠️  %s %s - Nginx CPU: %s\n", $1, $2, $9; alert_found=1 }
            }
            END { if (!alert_found) exit 1 }
            ' "$file" && alert_count=$((alert_count + 1))
        fi
    done
    
    if [[ $alert_count -eq 0 ]]; then
        echo "  ✅ No high CPU usage alerts found"
    fi
}

show_peak_usage() {
    echo "=== Peak Usage Analysis ==="
    
    for file in "$SCRIPT_DIR/logs/daily-summary-"*.log; do
        if [[ -f "$file" ]]; then
            echo ""
            echo "📅 File: $(basename $file)"
            echo ""
            
            echo "🔥 Peak CPU Usage (Top 3):"
            echo "Time     | Service | CPU%"
            echo "---------|---------|-----"
            awk -F',' 'NR>1 {
                if ($3 != "N/A" && $3 != "DOCKER_DOWN") print $2, "Moodle", $3
                if ($5 != "N/A" && $5 != "DOCKER_DOWN") print $2, "MariaDB", $5
                if ($7 != "N/A" && $7 != "DOCKER_DOWN") print $2, "Redis", $7
                if ($9 != "N/A" && $9 != "DOCKER_DOWN") print $2, "Nginx", $9
            }' "$file" | sort -k3 -nr | head -3 | awk '{printf "%-8s | %-7s | %s\n", $1, $2, $3}'
            
            echo ""
            echo "💾 Peak Memory Usage (Top 3):"
            echo "Time     | Service | RAM%"
            echo "---------|---------|-----"
            awk -F',' 'NR>1 {
                if ($4 != "N/A" && $4 != "DOCKER_DOWN") print $2, "Moodle", $4
                if ($6 != "N/A" && $6 != "DOCKER_DOWN") print $2, "MariaDB", $6
                if ($8 != "N/A" && $8 != "DOCKER_DOWN") print $2, "Redis", $8
                if ($10 != "N/A" && $10 != "DOCKER_DOWN") print $2, "Nginx", $10
            }' "$file" | sort -k3 -nr | head -3 | awk '{printf "%-8s | %-7s | %s\n", $1, $2, $3}'
            
            echo ""
        fi
    done
}

show_resource_overview() {
    echo "=== Resource Overview (Last 24 Hours) ==="
    echo ""
    
    today=$(date '+%Y-%m-%d')
    if [[ -f "$SCRIPT_DIR/logs/daily-summary-${today}.log" ]]; then
        echo "📊 Average Resource Usage:"
        echo "Service  | Avg CPU | Avg RAM | Peak CPU | Peak RAM"
        echo "---------|---------|---------|----------|----------"
        
        awk -F',' '
        NR>1 {
            if ($3 != "N/A" && $3 != "DOCKER_DOWN") { 
                moodle_cpu_sum += $3; moodle_cpu_count++; 
                if ($3 > moodle_cpu_peak) moodle_cpu_peak = $3 
            }
            if ($4 != "N/A" && $4 != "DOCKER_DOWN") { 
                moodle_mem_sum += $4; moodle_mem_count++; 
                if ($4 > moodle_mem_peak) moodle_mem_peak = $4 
            }
            if ($5 != "N/A" && $5 != "DOCKER_DOWN") { 
                mariadb_cpu_sum += $5; mariadb_cpu_count++; 
                if ($5 > mariadb_cpu_peak) mariadb_cpu_peak = $5 
            }
            if ($6 != "N/A" && $6 != "DOCKER_DOWN") { 
                mariadb_mem_sum += $6; mariadb_mem_count++; 
                if ($6 > mariadb_mem_peak) mariadb_mem_peak = $6 
            }
            if ($7 != "N/A" && $7 != "DOCKER_DOWN") { 
                redis_cpu_sum += $7; redis_cpu_count++; 
                if ($7 > redis_cpu_peak) redis_cpu_peak = $7 
            }
            if ($8 != "N/A" && $8 != "DOCKER_DOWN") { 
                redis_mem_sum += $8; redis_mem_count++; 
                if ($8 > redis_mem_peak) redis_mem_peak = $8 
            }
            if ($9 != "N/A" && $9 != "DOCKER_DOWN") { 
                nginx_cpu_sum += $9; nginx_cpu_count++; 
                if ($9 > nginx_cpu_peak) nginx_cpu_peak = $9 
            }
            if ($10 != "N/A" && $10 != "DOCKER_DOWN") { 
                nginx_mem_sum += $10; nginx_mem_count++; 
                if ($10 > nginx_mem_peak) nginx_mem_peak = $10 
            }
        }
        END {
            if (moodle_cpu_count > 0) 
                printf "%-8s | %6.1f%% | %6.1f%% | %7.1f%% | %7.1f%%\n", "Moodle", moodle_cpu_sum/moodle_cpu_count, moodle_mem_sum/moodle_mem_count, moodle_cpu_peak, moodle_mem_peak
            if (mariadb_cpu_count > 0) 
                printf "%-8s | %6.1f%% | %6.1f%% | %7.1f%% | %7.1f%%\n", "MariaDB", mariadb_cpu_sum/mariadb_cpu_count, mariadb_mem_sum/mariadb_mem_count, mariadb_cpu_peak, mariadb_mem_peak
            if (redis_cpu_count > 0) 
                printf "%-8s | %6.1f%% | %6.1f%% | %7.1f%% | %7.1f%%\n", "Redis", redis_cpu_sum/redis_cpu_count, redis_mem_sum/redis_mem_count, redis_cpu_peak, redis_mem_peak
            if (nginx_cpu_count > 0) 
                printf "%-8s | %6.1f%% | %6.1f%% | %7.1f%% | %7.1f%%\n", "Nginx", nginx_cpu_sum/nginx_cpu_count, nginx_mem_sum/nginx_mem_count, nginx_cpu_peak, nginx_mem_peak
        }' "$SCRIPT_DIR/logs/daily-summary-${today}.log"
        
        echo ""
        echo "📈 Data Points: $(tail -n +2 "$SCRIPT_DIR/logs/daily-summary-${today}.log" | wc -l) measurements today"
    else
        echo "❌ No data available for today"
    fi
}

generate_report() {
    echo "=== Comprehensive Resource Report ===" > "$SCRIPT_DIR/logs/daily-report.txt"
    echo "Generated: $(date)" >> "$SCRIPT_DIR/logs/daily-report.txt"
    echo "" >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    show_resource_overview >> "$SCRIPT_DIR/logs/daily-report.txt"
    echo "" >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    show_usage_graph >> "$SCRIPT_DIR/logs/daily-report.txt"
    echo "" >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    show_memory_alerts >> "$SCRIPT_DIR/logs/daily-report.txt"
    echo "" >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    show_peak_usage >> "$SCRIPT_DIR/logs/daily-report.txt"
    
    echo "📄 Comprehensive report saved to monitoring/logs/daily-report.txt"
}

case "${1:-overview}" in
    "overview")
        show_resource_overview
        ;;
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
        echo "Usage: $0 [overview|graph|alerts|peaks|report]"
        echo ""
        echo "Commands:"
        echo "  overview - Show resource summary with CPU & RAM averages/peaks"
        echo "  graph    - Show detailed CPU & RAM usage over time"
        echo "  alerts   - Show high resource usage alerts (CPU >90%, RAM >80%)"
        echo "  peaks    - Show peak usage analysis by service"
        echo "  report   - Generate comprehensive daily report"
        echo ""
        echo "Examples:"
        echo "  ./analyze-logs.sh overview  # Quick resource summary"
        echo "  ./analyze-logs.sh graph     # Detailed usage tables"
        echo "  ./analyze-logs.sh alerts    # Check for performance issues"
        ;;
esac