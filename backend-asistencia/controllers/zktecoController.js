const pool = require('../config/db');

// RUTA 1: Saludo y verificación del dispositivo biométrico ZKTeco
exports.handshake = (req, res) => {
    res.set('Content-Type', 'text/plain');
    res.send('OK');
};

// RUTA 2: Recepción y procesamiento de marcaciones faciales
exports.recibirMarcaciones = async (req, res) => {
    const numeroSerie = req.query.SN || 'DESCONOCIDO';
    const datosAsistencia = req.body;

    if (!datosAsistencia || typeof datosAsistencia !== 'string') {
        res.set('Content-Type', 'text/plain');
        return res.send('OK');
    }

    const lineas = datosAsistencia.trim().split('\n').filter(l => l.trim() !== '');
    console.log(`\n[ZKTeco ADMS] Recibidas ${lineas.length} marcaciones del lector ${numeroSerie}`);

    for (const linea of lineas) {
        // Formato habitual ZKTeco: PIN \t FechaHora \t Estado \t TipoVerificacion
        const partes = linea.split('\t');
        const pin = partes[0]?.trim();
        const fechaHoraStr = partes[1]?.trim();
        const estadoMarca = partes[2]?.trim() || '0';
        const tipoVerif = partes[3]?.trim() || '15'; // 15 = Reconocimiento facial

        if (!pin || !fechaHoraStr) continue;

        try {
            // 1. Guardar siempre en la bitácora cruda (marcaciones_raw)
            const insertRaw = `
                INSERT INTO marcaciones_raw (numero_serie_reloj, pin_biometrico, fecha_hora, estado_marcacion, tipo_verificacion)
                VALUES ($1, $2, $3, $4, $5)
            `;
            await pool.query(insertRaw, [numeroSerie, pin, fechaHoraStr, estadoMarca, tipoVerif]);

            // 2. Procesar y actualizar asistencia diaria consolidada
            const fechaHora = new Date(fechaHoraStr);
            const fechaSolo = fechaHoraStr.split(' ')[0]; // 'YYYY-MM-DD'
            const horaSolo = fechaHoraStr.split(' ')[1] || '00:00:00'; // 'HH:mm:ss'

            // Buscar estudiante por su PIN biométrico
            const queryEst = `
                SELECT e.id AS estudiante_id, gs.hora_ingreso, gs.tolerancia_minutos, gs.hora_limite_tardanza
                FROM estudiantes e
                LEFT JOIN grados_secciones gs ON e.grado_seccion_id = gs.id
                WHERE e.pin_biometrico = $1
            `;
            const resEst = await pool.query(queryEst, [pin]);

            if (resEst.rows.length > 0) {
                const est = resEst.rows[0];
                
                // Determinar estado de puntualidad (por defecto hora límite puntual 07:45)
                let estado = 'Puntual';
                const horaPartes = horaSolo.split(':');
                const minutosDelDia = parseInt(horaPartes[0], 10) * 60 + parseInt(horaPartes[1], 10);
                
                // Límite puntual: 7:45 AM (465 mins)
                // Límite tardanza: 8:15 AM (495 mins)
                if (minutosDelDia > 465 && minutosDelDia <= 495) {
                    estado = 'Tardanza';
                } else if (minutosDelDia > 495) {
                    estado = 'Tardanza Grave';
                }

                // Upsert en asistencias_diarias: si ya registró entrada hoy, actualizar salida; si no, registrar entrada
                const upsertAsistencia = `
                    INSERT INTO asistencias_diarias (estudiante_id, fecha, hora_ingreso, estado)
                    VALUES ($1, $2, $3, $4)
                    ON CONFLICT (estudiante_id, fecha)
                    DO UPDATE SET 
                        hora_salida = CASE 
                            WHEN asistencias_diarias.hora_ingreso IS NOT NULL AND asistencias_diarias.hora_ingreso <> EXCLUDED.hora_ingreso 
                            THEN EXCLUDED.hora_ingreso 
                            ELSE asistencias_diarias.hora_salida 
                        END,
                        actualizado_en = CURRENT_TIMESTAMP;
                `;
                await pool.query(upsertAsistencia, [est.estudiante_id, fechaSolo, horaSolo, estado]);
                console.log(`✔️ [OK] Asistencia procesada: Estudiante ID ${est.estudiante_id} (${pin}) - ${estado} a las ${horaSolo}`);
            } else {
                console.log(`ℹ️ Marcación recibida para PIN ${pin} (no vinculado a estudiante aún).`);
            }

        } catch (err) {
            console.error(`❌ Error procesando marcación ZKTeco (PIN ${pin}):`, err.message);
        }
    }

    // El protocolo ADMS de ZKTeco exige responder 'OK' como texto plano
    res.set('Content-Type', 'text/plain');
    res.send('OK');
};
