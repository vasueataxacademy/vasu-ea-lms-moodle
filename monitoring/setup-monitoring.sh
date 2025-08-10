#!/bin/bash

echo "=== Simple Resource Monitoring Setup ==="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make scripts executable
chmod +x "$SCRIPT_DIR/monitor-stats.sh"
chmod +x "$SCRIPT_DIR/analyze-logs.sh"

# Create initial log entry
"$SCRIPT_DIR/monitor-stats.sh" run

echo "✅ Monitoring scripts are ready!"
echo ""
echo "📊 Usage:"
echo "  ./monitoring/monitor-stats.sh run     - Log current stats"
echo "  ./monitoring/monitor-stats.sh show    - Show recent data"
echo "  ./monitoring/monitor-stats.sh analyze - Analyze trends"
echo "  ./monitoring/analyze-logs.sh graph    - Show usage graph"
echo "  ./monitoring/analyze-logs.sh alerts   - Check for high usage"
echo ""
echo "🔄 To automate logging every 5 minutes:"
echo "  ./monitoring/monitor-stats.sh setup"
echo ""
echo "📁 Log files location:"
echo "  monitoring/logs/container-stats.log   - Detailed container stats"
echo "  monitoring/logs/system-stats.log      - System resource usage"
echo "  monitoring/logs/daily-summary-*.log   - CSV format for analysis"
echo ""
echo "💡 Resource usage: ~5MB RAM, minimal CPU"
echo "💾 Storage: ~10MB per month"