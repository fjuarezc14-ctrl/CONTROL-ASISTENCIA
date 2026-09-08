FROM node:20-alpine

WORKDIR /app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm install --omit=dev

# Copiar el resto del código del backend y public
COPY . .

# Exponer el puerto interno de la aplicación
EXPOSE 3000

# Comando de inicio
CMD ["npm", "start"]
