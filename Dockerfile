# =========================================================
# Stage 1: Build Environment with Flutter SDK
# =========================================================
FROM ubuntu:22.04 AS build-stage

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/sdks/flutter/bin:${PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    ca-certificates \
    xz-utils \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Clone official Flutter stable repository
RUN git clone --depth 1 -b stable https://github.com/flutter/flutter.git /sdks/flutter && \
    flutter config --no-analytics && \
    flutter doctor -v

WORKDIR /app

# Copy pubspec files first to leverage Docker layer caching
COPY pubspec.yaml pubspec.lock ./

# Fetch dependencies
RUN flutter pub get

# Copy full application code
COPY . .

# Create dummy env file for build step if not present
RUN touch .env

# Analyze static code
RUN flutter analyze --no-fatal-warnings --no-fatal-infos

# Run unit & widget tests
RUN flutter test

# Enable Web & build Web release bundle
RUN flutter config --enable-web && \
    flutter build web --release

# =========================================================
# Stage 2: Production Nginx Web Server Container
# =========================================================
FROM nginx:1.25-alpine AS production-stage

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy compiled Flutter web assets from build stage
COPY --from=build-stage /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
