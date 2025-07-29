FROM bitnami/moodle:4.3.2

USER root

# Check PHP version and install Redis extension
RUN php -v && \
    install_packages php-redis || \
    install_packages php8.2-redis || \
    install_packages php8.1-redis

# Switch back to bitnami user
USER 1001