const pool = require('../config/db');

// Datos de contingencia / mock si la base de datos aún no tiene la tabla cargada
const MOCK_USUARIOS = [
    { id: 1, identificador: 'admin', password: 'admin', rol: 'admin', nombre: 'Administrador General VT' },
    { id: 1, identificador: 'admin', password: '12345', rol: 'admin', nombre: 'Administrador General VT' },
    { id: 2, identificador: 'aux_carmen', password: '12345', rol: 'admin', nombre: 'Personal de Control VT' },
    { id: 3, identificador: '45678901', password: '12345', rol: 'padre', nombre: 'María Torres Salazar' },
    { id: 4, identificador: '78901234', password: '12345', rol: 'padre', nombre: 'Roberto Mendoza Castro' }
];

exports.login = async (req, res) => {
    try {
        const { identificador, password } = req.body;

        if (!identificador || !password) {
            return res.status(400).json({ success: false, mensaje: 'Debe ingresar usuario/DNI y contraseña.' });
        }

        const idLimpio = identificador.toString().trim();
        const passLimpia = password.toString().trim();

        // 1. Consultar en PostgreSQL
        try {
            const query = `
                SELECT u.id, u.identificador, u.password_hash, u.nombre_completo, r.nombre AS rol_nombre,
                       a.id AS apoderado_id
                FROM usuarios u
                INNER JOIN roles r ON u.rol_id = r.id
                LEFT JOIN apoderados a ON a.usuario_id = u.id
                WHERE u.identificador = $1 AND u.activo = TRUE
            `;
            const result = await pool.query(query, [idLimpio]);

            if (result.rows.length > 0) {
                const user = result.rows[0];
                if (user.password_hash === passLimpia) {
                    const destino = user.rol_nombre === 'padre' ? 'vista_padre.html' : 'vista_admin.html';
                    return res.json({
                        success: true,
                        mensaje: 'Inicio de sesión exitoso',
                        usuario: {
                            id: user.id,
                            identificador: user.identificador,
                            nombre: user.nombre_completo,
                            rol: user.rol_nombre,
                            apoderado_id: user.apoderado_id || null
                        },
                        redirect: destino
                    });
                } else {
                    return res.status(401).json({ success: false, mensaje: 'Contraseña incorrecta.' });
                }
            }
        } catch (dbErr) {
            console.warn('ℹ️ Base de datos no inicializada o no accesible, usando fallback:', dbErr.message);
        }

        // 2. Fallback de prueba para desarrollo
        const mockUser = MOCK_USUARIOS.find(u => u.identificador === idLimpio && u.password === passLimpia);
        if (mockUser) {
            const destino = mockUser.rol === 'padre' ? 'vista_padre.html' : 'vista_admin.html';
            return res.json({
                success: true,
                mensaje: 'Inicio de sesión exitoso',
                usuario: {
                    id: mockUser.id,
                    identificador: mockUser.identificador,
                    nombre: mockUser.nombre,
                    rol: mockUser.rol,
                    apoderado_id: mockUser.rol === 'padre' ? 1 : null
                },
                redirect: destino
            });
        }

        return res.status(401).json({ success: false, mensaje: 'Usuario o DNI no encontrado, o contraseña errónea.' });

    } catch (error) {
        console.error('Error en login:', error);
        return res.status(500).json({ success: false, mensaje: 'Error interno del servidor.' });
    }
};
