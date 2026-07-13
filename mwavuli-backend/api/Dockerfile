FROM node:20-alpine
WORKDIR /app

# Install deps first for better layer caching.
COPY package.json ./
RUN npm install --no-audit --no-fund

COPY . .

EXPOSE 8080
# Run TypeScript directly with tsx (for production, `npm run build` + `npm start`).
CMD ["npx", "tsx", "src/server.ts"]
