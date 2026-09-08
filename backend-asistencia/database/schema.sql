-- =============================================================
-- ESQUEMA DE BASE DE DATOS: CONTROL DE ASISTENCIA ESCOLAR ZKTECO
-- =============================================================

-- 1. TABLA DE ROLES
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL, -- 'admin', 'auxiliar', 'padre'
    descripcion TEXT
);

-- 2. TABLA DE USUARIOS DEL SISTEMA
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    rol_id INT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    identificador VARCHAR(50) UNIQUE NOT NULL, -- DNI para padres, username institucional para auxiliares
    password_hash VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    correo VARCHAR(100),
    activo BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. TABLA DE GRADOS Y SECCIONES
CREATE TABLE IF NOT EXISTS grados_secciones (
    id SERIAL PRIMARY KEY,
    nivel VARCHAR(50) NOT NULL, -- 'Primaria', 'Secundaria', 'Inicial'
    grado VARCHAR(50) NOT NULL, -- '1er Grado', '2do Grado', etc.
    seccion VARCHAR(10) NOT NULL, -- 'A', 'B', 'C'
    hora_ingreso TIME DEFAULT '07:30:00',
    tolerancia_minutos INT DEFAULT 15, -- Hasta 07:45 es puntual
    hora_limite_tardanza TIME DEFAULT '08:15:00', -- Pasado esto es falta
    CONSTRAINT uq_nivel_grado_seccion UNIQUE (nivel, grado, seccion)
);

-- 4. TABLA DE ESTUDIANTES
CREATE TABLE IF NOT EXISTS estudiantes (
    id SERIAL PRIMARY KEY,
    codigo_estudiante VARCHAR(50) UNIQUE NOT NULL, -- E001 o DNI del alumno
    pin_biometrico VARCHAR(50) UNIQUE NOT NULL, -- PIN configurado en el reloj facial ZKTeco
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    grado_seccion_id INT REFERENCES grados_secciones(id) ON DELETE SET NULL,
    foto_url TEXT,
    activo BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. TABLA DE APODERADOS (PADRES DE FAMILIA)
CREATE TABLE IF NOT EXISTS apoderados (
    id SERIAL PRIMARY KEY,
    usuario_id INT UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    dni VARCHAR(15) UNIQUE NOT NULL,
    nombres_completos VARCHAR(150) NOT NULL,
    telefono_whatsapp VARCHAR(20) NOT NULL,
    correo VARCHAR(100),
    direccion TEXT
);

-- 6. RELACIÓN MULTIHIJO (ESTUDIANTE <-> APODERADOS)
CREATE TABLE IF NOT EXISTS estudiante_apoderado (
    id SERIAL PRIMARY KEY,
    estudiante_id INT NOT NULL REFERENCES estudiantes(id) ON DELETE CASCADE,
    apoderado_id INT NOT NULL REFERENCES apoderados(id) ON DELETE CASCADE,
    parentesco VARCHAR(50) DEFAULT 'Padre', -- 'Padre', 'Madre', 'Tutor Legal'
    es_contacto_principal BOOLEAN DEFAULT TRUE,
    CONSTRAINT uq_estudiante_apoderado UNIQUE (estudiante_id, apoderado_id)
);

-- 7. TABLA DE MARCACIONES EN BRUTO (LOGS DIRECTOS DEL RELOJ ZKTECO)
CREATE TABLE IF NOT EXISTS marcaciones_raw (
    id BIGSERIAL PRIMARY KEY,
    numero_serie_reloj VARCHAR(100) NOT NULL,
    pin_biometrico VARCHAR(50) NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,
    estado_marcacion VARCHAR(10), -- '0' entrada, '1' salida
    tipo_verificacion VARCHAR(10), -- '15' rostro, '1' huella, '2' tarjeta
    recibido_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. TABLA DE ASISTENCIAS DIARIAS CONSOLIDADAS
CREATE TABLE IF NOT EXISTS asistencias_diarias (
    id BIGSERIAL PRIMARY KEY,
    estudiante_id INT NOT NULL REFERENCES estudiantes(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    hora_ingreso TIME,
    hora_salida TIME,
    estado VARCHAR(20) NOT NULL DEFAULT 'Falta', -- 'Puntual', 'Tardanza', 'Falta', 'Justificada'
    justificacion_motivo TEXT,
    justificado_por INT REFERENCES usuarios(id),
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_estudiante_fecha UNIQUE (estudiante_id, fecha)
);

-- ÍNDICES PARA BÚSQUEDAS RÁPIDAS
CREATE INDEX IF NOT EXISTS idx_marcaciones_pin_fecha ON marcaciones_raw(pin_biometrico, fecha_hora);
CREATE INDEX IF NOT EXISTS idx_asistencias_fecha_estado ON asistencias_diarias(fecha, estado);
CREATE INDEX IF NOT EXISTS idx_estudiantes_grado ON estudiantes(grado_seccion_id);
CREATE INDEX IF NOT EXISTS idx_apoderados_dni ON apoderados(dni);

-- =============================================================
-- DATOS SEMILLA (INICIALES DE PRUEBA)
-- =============================================================

INSERT INTO roles (id, nombre, descripcion) VALUES 
(1, 'admin', 'Administrador General del Sistema'),
(2, 'auxiliar', 'Auxiliar de Asistencia y Disciplina'),
(3, 'padre', 'Padre de Familia o Apoderado')
ON CONFLICT (id) DO NOTHING;

-- Usuarios de prueba
INSERT INTO usuarios (id, rol_id, identificador, password_hash, nombre_completo, telefono, correo) VALUES 
(1, 2, 'aux_carmen', '12345', 'Carmen Rojas Mendoza', '987654320', 'carmen.rojas@colegio.edu.pe'),
(2, 3, '45678901', '12345', 'María Torres Salazar', '999888777', 'maria.torres@gmail.com'),
(3, 3, '78901234', '12345', 'Roberto Mendoza Castro', '987654321', 'roberto.m@gmail.com')
ON CONFLICT (id) DO NOTHING;

-- Grados y Secciones
INSERT INTO grados_secciones (id, nivel, grado, seccion, hora_ingreso, tolerancia_minutos, hora_limite_tardanza) VALUES 
(1, 'Secundaria', '3er Grado', 'A', '07:30:00', 15, '08:15:00'),
(2, 'Primaria', '5to Grado', 'B', '07:45:00', 15, '08:30:00'),
(3, 'Secundaria', '4to Grado', 'C', '07:30:00', 15, '08:15:00'),
(4, 'Primaria', '1er Grado', 'A', '07:45:00', 15, '08:30:00')
ON CONFLICT (id) DO NOTHING;

-- Apoderados
INSERT INTO apoderados (id, usuario_id, dni, nombres_completos, telefono_whatsapp, correo, direccion) VALUES 
(1, 2, '45678901', 'María Torres Salazar', '999888777', 'maria.torres@gmail.com', 'Calle Los Pinos 456, Centro'),
(2, 3, '78901234', 'Roberto Mendoza Castro', '987654321', 'roberto.m@gmail.com', 'Av. Las Flores 123, Urb. San Carlos')
ON CONFLICT (id) DO NOTHING;

-- Estudiantes (PIN coincide con el ID de usuario en el ZKTeco)
INSERT INTO estudiantes (id, codigo_estudiante, pin_biometrico, nombres, apellidos, grado_seccion_id) VALUES 
(1, 'E001', '101', 'Carlos', 'Mendoza Ruiz', 1),
(2, 'E002', '102', 'Lucía', 'Gómez Torres', 1),
(3, 'E003', '103', 'Mateo', 'Gómez Torres', 2),
(4, 'E004', '104', 'Sofía', 'Castro Díaz', 3),
(5, 'E005', '105', 'Diego', 'Ramos Vega', 4)
ON CONFLICT (id) DO NOTHING;

-- Relación Familia Gómez Torres (María Torres tiene 2 hijos: Lucía en 3ro Sec y Mateo en 5to Prim)
INSERT INTO estudiante_apoderado (estudiante_id, apoderado_id, parentesco) VALUES 
(2, 1, 'Madre'),
(3, 1, 'Madre'),
(1, 2, 'Padre')
ON CONFLICT DO NOTHING;
