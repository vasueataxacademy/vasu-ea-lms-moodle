#!/bin/bash

echo "=== Simple Resource Monitoring Setup ==="
echo ""

# Make scripts executable
chmod +x monitor-stats.sh
chmod +x analyze-logs.sh

# Create initial log entry
./monitor-stats.sh run

echo "✅ Monitoring scripts are ready!"
echo ""
echo "📊 Usage:"
echo "  ./monitor-stats.sh run     - Log current stats"
echo "  ./monitor-stats.sh show    - Show recent data"
echo "  ./monitor-stats.sh analyze - Analyze trends"
echo "  ./analyze-logs.sh graph    - Show usage graph"
echo "  ./analyze-logs.sh alerts   - Check for high usage"
echo ""
echo "🔄 To automate logging every 5 minutes:"
echo "  ./monitor-stats.sh setup"
echo ""
echo "📁 Log files location:"
echo "  monitoring/logs/container-stats.log   - Detailed container stats"
echo "  monitoring/logs/system-stats.log      - System resource usage"
echo "  monitoring/logs/daily-summary-*.log   - CSV format for analysis"
echo ""
echo "💡 Resource usage: ~5MB RAM, minimal CPU"
echo "💾 Storage: ~10MB per month"