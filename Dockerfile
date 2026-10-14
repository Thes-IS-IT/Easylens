# =========================================================
# EasyLens Application Portal & Web Container
# =========================================================
FROM nginx:1.25-alpine AS production-stage

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy application portal HTML and branding assets
COPY download_landing.html /usr/share/nginx/html/index.html
COPY assets/mascots/app_logo.png /usr/share/nginx/html/app_logo.png
COPY assets/mascots/app_mascot.png /usr/share/nginx/html/app_mascot.png

# Prepare downloads directory
RUN mkdir -p /usr/share/nginx/html/downloads

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
