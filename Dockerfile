# =========================================================
# Stage 1: Asset Preparation & Verification
# =========================================================
FROM alpine:3.19 AS asset-stage

WORKDIR /app

# Copy application portal HTML and branding assets
COPY download_landing.html ./index.html
COPY assets/mascots/app_logo.png ./app_logo.png
COPY assets/mascots/app_mascot.png ./app_mascot.png

# Verify assets exist and create downloads placeholder directory
RUN test -f ./index.html && \
    test -f ./app_logo.png && \
    test -f ./app_mascot.png && \
    mkdir -p ./downloads

# =========================================================
# Stage 2: Hardened NGINX Minimal Production Server
# =========================================================
FROM nginx:1.25-alpine AS production-stage

# Container Metadata
LABEL maintainer="Thes-IS-IT Research Team <easylens.dev@gmail.com>" \
      description="EasyLens Production Web Portal & Application Distribution Container" \
      version="1.0.27"

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy verified web assets from asset-stage
COPY --from=asset-stage /app/index.html /usr/share/nginx/html/index.html
COPY --from=asset-stage /app/app_logo.png /usr/share/nginx/html/app_logo.png
COPY --from=asset-stage /app/app_mascot.png /usr/share/nginx/html/app_mascot.png
COPY --from=asset-stage /app/downloads /usr/share/nginx/html/downloads

# Enforce secure least-privilege ownership and permissions
RUN chmod -R 755 /usr/share/nginx/html && \
    chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 80

# Resilient dual-stack healthcheck (IPv4 and IPv6 loopback) with start period
HEALTHCHECK --interval=15s --timeout=3s --retries=3 --start-period=5s \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/ || wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
