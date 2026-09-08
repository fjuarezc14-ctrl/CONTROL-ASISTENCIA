FROM node:20-alpine

WORKDIR /app

# Instalar dependencias con tolerancia a fallos
COPY package*.json ./

RUN npm install --omit=dev --legacy-peer-deps --no-audit --no-fund

# Copiar el código fuente
COPY . .

# Exponer el puerto interno
EXPOSE 3000

# Iniciar servidor
CMD ["npm", "start"]
