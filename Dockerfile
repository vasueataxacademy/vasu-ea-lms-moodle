FROM bitnami/moodle:4.3.2

USER root

# Install Redis PHP extension using pecl
RUN pecl install redis && \
    echo "extension=redis.so" >> /opt/bitnami/php/etc/php.ini

# Switch back to bitnami user
USER 1001