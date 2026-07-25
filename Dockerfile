# =========================================================
# Stage 1: Mobile Android Build Environment
# =========================================================
FROM ubuntu:22.04 AS build-stage

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
ENV ANDROID_SDK_ROOT="/sdks/android"
ENV PATH="${PATH}:/sdks/flutter/bin:/sdks/android/cmdline-tools/latest/bin:/sdks/android/platform-tools:${JAVA_HOME}/bin"

# Install system dependencies & Java 17
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    ca-certificates \
    xz-utils \
    libgomp1 \
    openjdk-17-jdk-headless \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Android SDK Command-line tools & platforms
RUN mkdir -p /sdks/android/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /sdks/android/cmdline-tools && \
    mv /sdks/android/cmdline-tools/cmdline-tools /sdks/android/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip && \
    yes | sdkmanager --licenses || true && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Clone official Flutter stable SDK
RUN git clone --depth 1 -b stable https://github.com/flutter/flutter.git /sdks/flutter && \
    flutter config --no-analytics && \
    flutter doctor -v

WORKDIR /app

# Copy pubspec files for caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code
COPY . .
RUN touch .env

# Analyze static code
RUN flutter analyze --no-fatal-warnings --no-fatal-infos

# Run unit tests
RUN flutter test

# Build Android Release APK (Mobile target)
RUN flutter build apk --release --no-tree-shake-icons

# =========================================================
# Stage 2: Mobile APK Web Distribution Server
# =========================================================
FROM nginx:1.25-alpine AS production-stage

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY download_landing.html /usr/share/nginx/html/index.html
COPY --from=build-stage /app/build/app/outputs/flutter-apk/app-release.apk /usr/share/nginx/html/easylens-release.apk

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
