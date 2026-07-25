# =========================================================
# EasyLens Mobile APK Web Distribution Container
# =========================================================
FROM nginx:1.25-alpine AS production-stage

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy mobile landing page HTML
COPY download_landing.html /usr/share/nginx/html/index.html

# Copy compiled Android APK file into web distribution directory
COPY build/app/outputs/flutter-apk/app-release.apk /usr/share/nginx/html/easylens-release.apk

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
