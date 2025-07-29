FROM bitnami/moodle:4.3.2

USER root

# Install Redis extension using pecl (simpler approach)
RUN apt-get update && \
    apt-get install -y build-essential php-dev php-pear && \
    printf "\n" | pecl install redis && \
    echo "extension=redis.so" > /opt/bitnami/php/etc/conf.d/redis.ini && \
    apt-get remove -y build-essential php-dev php-pear && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch back to bitnami user
USER 1001