const express = require('express');
const { Pool } = require('pg'); // Importamos PostgreSQL

const app = express();
app.use(express.static('public'));
app.use(express.text({ type: '*/*' }));

// -------------------------------------------------------------
// CONFIGURACIÓN DE POSTGRESQL
// -------------------------------------------------------------
const pool = new Pool({
    user: 'postgres',     // <-- CAMBIA ESTO (ej. 'postgres')
    host: 'localhost',               // O la IP de tu servidor
    database: 'db_st',    // <-- CAMBIA ESTO (ej. 'colegio_st')
    password: 'admin123',       // <-- CAMBIA ESTO
    port: 5432,                      // Puerto por defecto de Postgres
});

// Verificamos si hay conexión a la BD al arrancar
pool.connect()
    .then(() => console.log('✅ Conectado exitosamente a PostgreSQL'))
    .catch(err => console.error('❌ Error conectando a PostgreSQL:', err.message));


// -------------------------------------------------------------
// RUTA 1: EL SALUDO
// -------------------------------------------------------------
app.get('/iclock/cdata', (req, res) => {
    res.set('Content-Type', 'text/plain');
    res.send('OK');
});

// -------------------------------------------------------------
// RUTA 2: RECIBIR Y GUARDAR LA MARCACIÓN
// -------------------------------------------------------------
app.post('/iclock/cdata', async (req, res) => {
    const numeroSerie = req.query.SN || 'DESCONOCIDO';
    const datosAsistencia = req.body; 
    
    // ZKTeco puede enviar varias marcaciones de golpe en múltiples líneas
    // Separamos el texto por saltos de línea y filtramos las vacías
    const lineas = datosAsistencia.trim().split('\n').filter(line => line.trim() !== '');

    console.log(`\n[PROCESANDO] ${lineas.length} marcaciones recibidas del reloj ${numeroSerie}`);

    for (const linea of lineas) {
        // Separamos cada línea usando tabulaciones (\t)
        const [pin, fechaHora, estado, tipo] = linea.split('\t');

        try {
            // Guardamos en PostgreSQL
            const query = `
                INSERT INTO asistencias (numero_serie_reloj, estudiante_pin, fecha_hora, estado_marcacion, tipo_verificacion) 
                VALUES ($1, $2, $3, $4, $5)
            `;
            const valores = [numeroSerie, pin, fechaHora, estado, tipo];
            
            await pool.query(query, valores);
            console.log(`✔️ Asistencia guardada: Estudiante ${pin} a las ${fechaHora}`);

        } catch (error) {
            console.error(`❌ Error guardando estudiante ${pin}:`, error.message);
        }
    }

    // Se responde con OK al reloj
    res.set('Content-Type', 'text/plain');
    res.send('OK');
});

// -------------------------------------------------------------
// ENCENDER EL SERVIDOR
// -------------------------------------------------------------
const PUERTO = 3000;
app.listen(PUERTO, () => {
    console.log(`🚀 Servidor ZKTeco escuchando en el puerto ${PUERTO}`);
});