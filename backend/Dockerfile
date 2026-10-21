FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY server.js egypt_local_time.js noise_guard.js view_as.js shop_drawing.js invoices_owner.js expense_statements.js attachments.js withdrawal_files_reports.js meetings.js cont_invoices.js invoice_structure.js cont_progress.js ./
COPY lib ./lib
COPY scripts/lib ./scripts/lib
COPY scripts/seed_z1_emaar_f_project_locations.sql ./scripts/seed_z1_emaar_f_project_locations.sql
EXPOSE 3000
CMD ["node", "server.js"]
