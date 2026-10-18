# Given. A tiny web service that says which container answered and which
# version it runs: ideal to watch load balancing and rolling updates.
FROM nginx:1.31.7-alpine
ARG APP_VERSION=1
ENV APP_VERSION=${APP_VERSION}
LABEL org.opencontainers.image.title="cao-hello"
# The official nginx image renders /etc/nginx/templates/*.template with
# the container's environment variables when it starts.
COPY default.conf.template /etc/nginx/templates/default.conf.template
HEALTHCHECK --interval=5s --timeout=2s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/health || exit 1
