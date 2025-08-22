FROM bitnami/moodle:4.3.2

USER root

# Copy custom PHP-FPM pool config
COPY php/php-fpm.conf /opt/bitnami/php/etc/php-fpm.d/www.conf

# Install Redis extension and curl for healthchecks
RUN apt-get update && \
    apt-get install -y build-essential php-dev php-pear curl && \
    printf "\n" | pecl install redis && \
    echo "extension=redis.so" > /opt/bitnami/php/etc/conf.d/redis.ini && \
    apt-get remove -y build-essential php-dev php-pear && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch back to bitnami user
USER 1001