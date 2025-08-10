#!/bin/bash

# Simple monitoring service script
# This creates a background process that runs monitoring every 5 minutes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/monitoring.pid"
LOG_FILE="$SCRIPT_DIR/logs/monitoring-service.log"

start_monitoring() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Monitoring service is already running (PID: $(cat "$PID_FILE"))"
        return 1
    fi
    
    echo "Starting monitoring service..."
    mkdir -p "$SCRIPT_DIR/logs"
    
    # Start monitoring loop in background
    (
        while true; do
            echo "$(date): Running monitoring..." >> "$LOG_FILE"
            "$SCRIPT_DIR/monitor-stats.sh" run >> "$LOG_FILE" 2>&1
            echo "$(date): Monitoring completed. Next run in 5 minutes..." >> "$LOG_FILE"
            sleep 300  # 5 minutes
        done
    ) &
    
    # Save PID
    echo $! > "$PID_FILE"
    echo "✅ Monitoring service started (PID: $!)"
    echo "📄 Logs: $LOG_FILE"
    echo "🛑 Stop with: $0 stop"
}

stop_monitoring() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            rm -f "$PID_FILE"
            echo "✅ Monitoring service stopped"
        else
            echo "❌ Process not running, cleaning up PID file"
            rm -f "$PID_FILE"
        fi
    else
        echo "❌ Monitoring service is not running"
    fi
}

status_monitoring() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "✅ Monitoring service is running (PID: $(cat "$PID_FILE"))"
        echo "📄 Log file: $LOG_FILE"
        if [[ -f "$LOG_FILE" ]]; then
            echo "📊 Last 5 log entries:"
            tail -5 "$LOG_FILE"
        fi
    else
        echo "❌ Monitoring service is not running"
        if [[ -f "$PID_FILE" ]]; then
            rm -f "$PID_FILE"
        fi
    fi
}

case "${1:-help}" in
    "start")
        start_monitoring
        ;;
    "stop")
        stop_monitoring
        ;;
    "restart")
        stop_monitoring
        sleep 2
        start_monitoring
        ;;
    "status")
        status_monitoring
        ;;
    "logs")
        if [[ -f "$LOG_FILE" ]]; then
            tail -f "$LOG_FILE"
        else
            echo "No log file found at $LOG_FILE"
        fi
        ;;
    *)
        echo "Usage: $0 [start|stop|restart|status|logs]"
        echo ""
        echo "Commands:"
        echo "  start   - Start monitoring service in background"
        echo "  stop    - Stop monitoring service"
        echo "  restart - Restart monitoring service"
        echo "  status  - Check service status"
        echo "  logs    - Follow service logs"
        echo ""
        echo "This service runs monitoring every 5 minutes automatically."
        ;;
esac