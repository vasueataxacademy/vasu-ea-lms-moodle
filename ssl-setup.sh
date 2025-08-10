#!/bin/bash

# SSL Certificate Setup Helper Script

set -e

echo "=== SSL Certificate Setup ==="
echo ""

# Check if domain is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <domain> [email]"
    echo ""
    echo "Examples:"
    echo "  $0 subdomain.yourdomain.com                    # Subdomain certificate"
    echo "  $0 '*.yourdomain.com' admin@yourdomain.com     # Wildcard certificate"
    echo ""
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-admin@$(echo $DOMAIN | sed 's/^\*\.//')}"

echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Check if it's a wildcard certificate
if [[ "$DOMAIN" == *"*"* ]]; then
    echo "🌟 Setting up WILDCARD certificate for $DOMAIN"
    echo "⚠️  This requires DNS validation - you'll need to add TXT records"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    echo "🛑 Stopping nginx..."
    docker-compose stop nginx
    
    echo "🔐 Requesting wildcard certificate..."
    docker-compose -f docker-compose.ssl.yml run --rm -it certbot \
        certonly --manual \
        --preferred-challenges dns \
        -d "$DOMAIN" \
        --agree-tos \
        --email "$EMAIL"
        
else
    echo "📋 Setting up SUBDOMAIN certificate for $DOMAIN"
    echo "✅ This uses HTTP validation - fully automated"
    echo ""
    
    echo "🛑 Stopping nginx..."
    docker-compose stop nginx
    
    echo "🔐 Requesting subdomain certificate..."
    docker-compose -f docker-compose.ssl.yml run --rm certbot \
        certonly --webroot -w /usr/share/nginx/html \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL"
fi

echo ""
echo "🚀 Starting nginx..."
docker-compose start nginx

echo ""
echo "✅ SSL certificate setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Update nginx.conf with your domain and certificate paths"
echo "2. Test your HTTPS setup: https://$DOMAIN"
echo "3. Set up automatic renewal (see README for cron job setup)"