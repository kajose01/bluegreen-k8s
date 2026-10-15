FROM node:20-alpine
WORKDIR /app
COPY package.json server.js version.json ./
ENV NODE_ENV=production
USER node
EXPOSE 3000
CMD ["node", "server.js"]
