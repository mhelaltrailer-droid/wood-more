FROM node:20-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY server.js ./
COPY scripts/lib ./scripts/lib
COPY scripts/seed_z1_emaar_f_project_locations.sql ./scripts/seed_z1_emaar_f_project_locations.sql
EXPOSE 3000
CMD ["node", "server.js"]