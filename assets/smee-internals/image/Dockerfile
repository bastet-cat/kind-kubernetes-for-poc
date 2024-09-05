FROM node:18
WORKDIR /app
COPY src/package*.json ./
RUN npm install
COPY index.js ./
CMD ["npm", "start"]
