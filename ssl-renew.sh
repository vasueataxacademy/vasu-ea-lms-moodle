#!/bin/bash

# SSL Certificate Renewal Helper Script

set -e

echo "=== SSL Certificate Renewal ==="
echo ""

# Check if manual renewal is needed
MANUAL_RENEWAL=false
if [ "$1" = "--manual" ] || [ "$1" = "-m" ]; then
    MANUAL_RENEWAL=true
    echo "🔧 Manual renewal mode (for wildcard certificates)"
else
    echo "🔄 Automatic renewal mode (for subdomain certificates)"
fi

echo ""

# Check existing certificates
echo "📋 Checking existing certificates..."
if docker-compose -f docker-compose.ssl.yml run --rm certbot certificates 2>/dev/null | grep -q "Certificate Name:"; then
    echo "✅ Found existing certificates"
    docker-compose -f docker-compose.ssl.yml run --rm certbot certificates
else
    echo "❌ No certificates found. Run ./ssl-setup.sh first."
    exit 1
fi

echo ""
read -p "Continue with renewal? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo "🛑 Stopping nginx..."
docker-compose stop nginx

if [ "$MANUAL_RENEWAL" = true ]; then
    echo "🔐 Running manual renewal (DNS validation required)..."
    docker-compose -f docker-compose.ssl.yml run --rm -it certbot \
        renew --manual --preferred-challenges dns
else
    echo "🔐 Running automatic renewal..."
    docker-compose -f docker-compose.ssl.yml run --rm certbot \
        renew --webroot -w /usr/share/nginx/html
fi

echo ""
echo "🚀 Starting nginx..."
docker-compose start nginx

echo ""
echo "✅ SSL certificate renewal complete!"
echo ""
echo "📝 Certificate status:"
docker-compose -f docker-compose.ssl.yml run --rm certbot certificates