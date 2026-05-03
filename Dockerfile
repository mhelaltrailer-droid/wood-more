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
# nginx.compose.conf: proxy /api/ → api:3000 (Docker Compose). standalone: no proxy (Render).
COPY nginx.conf /etc/nginx/nginx.compose.conf
COPY nginx.standalone.conf /etc/nginx/nginx.standalone.conf
COPY docker-entrypoint-web.sh /docker-entrypoint-web.sh
RUN chmod +x /docker-entrypoint-web.sh
EXPOSE 80
# Entrypoint: listen on $PORT for Render; skip api upstream when "api" host missing
CMD ["/docker-entrypoint-web.sh"]
