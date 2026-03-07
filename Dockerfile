# Build stage: compile Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app

# Install dependencies first (better layer caching)
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Copy source and build for web
COPY . .
RUN flutter build web --release

# Run stage: serve with nginx
FROM nginx:alpine
# Remove default static content
RUN rm -rf /usr/share/nginx/html/*
# Copy built Flutter web app
COPY --from=builder /app/build/web /usr/share/nginx/html
# SPA routing: fallback to index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
