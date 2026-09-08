const express = require('express');
const pool = require('./config/db');

// Importar rutas modulares
const authRoutes = require('./routes/authRoutes');
const zktecoRoutes = require('./routes/zktecoRoutes');
const apiRoutes = require('./routes/apiRoutes');

const app = express();

// Middlewares
app.use(express.static('public'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Middleware para soportar texto crudo tabulado enviado por ZKTeco
app.use(express.text({ type: '*/*' }));

// Verificación de conexión a PostgreSQL
pool.connect()
    .then(client => {
        console.log('✅ Conectado exitosamente al servidor PostgreSQL');
        client.release();
    })
    .catch(err => {
        console.warn('⚠️ Nota: PostgreSQL no está respondiendo en este momento (', err.message, '). El sistema operará con modo resiliente/fallback.');
    });

// Montar Rutas
app.use('/api/auth', authRoutes);
app.use('/api', apiRoutes);
app.use('/iclock', zktecoRoutes);

// Manejo de errores 404 para API
app.use('/api', (req, res) => {
    res.status(404).json({ success: false, mensaje: 'Ruta API no encontrada' });
});

// Encender Servidor
const PUERTO = process.env.PORT || 3000;
app.listen(PUERTO, () => {
    console.log(`\n======================================================`);
    console.log(`🚀 Sistema de Control de Asistencia Escolar Activo`);
    console.log(`📍 Servidor Web:      http://localhost:${PUERTO}`);
    console.log(`📍 Endpoint ZKTeco:   http://localhost:${PUERTO}/iclock/cdata`);
    console.log(`======================================================\n`);
});