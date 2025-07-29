FROM bitnami/moodle:4.3.2

USER root

# Install Redis PHP extension
RUN install_packages php-redis

# Switch back to bitnami user
USER 1001