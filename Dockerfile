# syntax=docker/dockerfile:1
# The shop image (given, the Lab 5 solution): WordPress (official image, pinned) + WooCommerce + WP-CLI
# + PHP upload settings. No password, no site data in the image.

ARG WORDPRESS_TAG=7.1.3-php8.4-apache

# Stage 1: fetch and unzip WooCommerce; wget and unzip stay here.
FROM alpine:3.24.2 AS plugins
ARG WOOCOMMERCE_VERSION=11.2.1
ARG WOOCOMMERCE_URL=https://downloads.wordpress.org/plugin/woocommerce.${WOOCOMMERCE_VERSION}.zip
RUN wget -q -O /tmp/woocommerce.zip "${WOOCOMMERCE_URL}" \
 && mkdir /plugins \
 && unzip -q /tmp/woocommerce.zip -d /plugins

# Stage 2: the image you ship.
FROM wordpress:${WORDPRESS_TAG}
ARG WPCLI_VERSION=2.12.0

LABEL org.opencontainers.image.title="cao-shop" \
      org.opencontainers.image.description="SESAME Shop: WordPress with WooCommerce and WP-CLI" \
      org.opencontainers.image.source="https://github.com/SESAME-U"

COPY --from=plugins --chown=www-data:www-data /plugins/woocommerce /usr/src/wordpress/wp-content/plugins/woocommerce
ADD --chmod=755 https://github.com/wp-cli/wp-cli/releases/download/v${WPCLI_VERSION}/wp-cli-${WPCLI_VERSION}.phar /usr/local/bin/wp
COPY config/uploads.ini /usr/local/etc/php/conf.d/uploads.ini

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -fsS -o /dev/null http://localhost/wp-login.php || exit 1
