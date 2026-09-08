-- =============================================================
-- ASISTENCIA VT by VALETEC - ESQUEMA DE BASE DE DATOS
-- Sistema de Control Biométrico y Gestión de Asistencia
-- Aplicable a: Colegios, Academias, Institutos y Centros Educativos
-- =============================================================

-- 1. TABLA DE ROLES
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL, -- 'admin', 'supervisor', 'padre'
    descripcion TEXT
);

-- 2. TABLA DE USUARIOS DEL SISTEMA
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    rol_id INT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    identificador VARCHAR(50) UNIQUE NOT NULL, -- DNI para apoderados, username para administradores
    password_hash VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    correo VARCHAR(100),
    activo BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. TABLA DE GRUPOS, AULAS O CICLOS
CREATE TABLE IF NOT EXISTS grados_secciones (
    id SERIAL PRIMARY KEY,
    nivel VARCHAR(50) NOT NULL, -- 'Secundaria', 'Primaria', 'Pre-Universitario', 'Ciclo Regular', etc.
    grado VARCHAR(50) NOT NULL, -- 'Aula 101', 'Grupo A', '1er Grado', 'Ciclo Anual'
    seccion VARCHAR(10) NOT NULL, -- 'A', 'B', 'C', 'U'
    hora_ingreso TIME DEFAULT '07:30:00',
    tolerancia_minutos INT DEFAULT 15, -- Hasta 07:45 es puntual
    hora_limite_tardanza TIME DEFAULT '08:15:00', -- Pasado esto es falta
    CONSTRAINT uq_nivel_grado_seccion UNIQUE (nivel, grado, seccion)
);

-- 4. TABLA DE ESTUDIANTES / ALUMNOS
CREATE TABLE IF NOT EXISTS estudiantes (
    id SERIAL PRIMARY KEY,
    dni VARCHAR(15) UNIQUE, -- DNI del estudiante para búsquedas rápidas
    codigo_estudiante VARCHAR(50) UNIQUE NOT NULL, -- Código institucional
    pin_biometrico VARCHAR(50) UNIQUE NOT NULL, -- PIN configurado en el lector facial ZKTeco
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    grado_seccion_id INT REFERENCES grados_secciones(id) ON DELETE SET NULL,
    foto_url TEXT,
    activo BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. TABLA DE APODERADOS / CONTACTOS DE EMERGENCIA
CREATE TABLE IF NOT EXISTS apoderados (
    id SERIAL PRIMARY KEY,
    usuario_id INT UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    dni VARCHAR(15) UNIQUE NOT NULL,
    nombres_completos VARCHAR(150) NOT NULL,
    telefono_whatsapp VARCHAR(20) NOT NULL,
    correo VARCHAR(100),
    direccion TEXT
);

-- 6. RELACIÓN MULTIHIJO / VINCULACIÓN FAMILIAR
CREATE TABLE IF NOT EXISTS estudiante_apoderado (
    id SERIAL PRIMARY KEY,
    estudiante_id INT NOT NULL REFERENCES estudiantes(id) ON DELETE CASCADE,
    apoderado_id INT NOT NULL REFERENCES apoderados(id) ON DELETE CASCADE,
    parentesco VARCHAR(50) DEFAULT 'Apoderado', -- 'Padre', 'Madre', 'Tutor Legal'
    es_contacto_principal BOOLEAN DEFAULT TRUE,
    CONSTRAINT uq_estudiante_apoderado UNIQUE (estudiante_id, apoderado_id)
);

-- 7. TABLA DE MARCACIONES EN BRUTO (LOGS DEL RELOJ ZKTECO)
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

-- ÍNDICES PARA BÚSQUEDAS RÁPIDAS POR DNI, CÓDIGO Y FECHA
CREATE INDEX IF NOT EXISTS idx_estudiantes_dni ON estudiantes(dni);
CREATE INDEX IF NOT EXISTS idx_estudiantes_codigo ON estudiantes(codigo_estudiante);
CREATE INDEX IF NOT EXISTS idx_marcaciones_pin_fecha ON marcaciones_raw(pin_biometrico, fecha_hora);
CREATE INDEX IF NOT EXISTS idx_asistencias_fecha_estado ON asistencias_diarias(fecha, estado);
CREATE INDEX IF NOT EXISTS idx_estudiantes_grado ON estudiantes(grado_seccion_id);
CREATE INDEX IF NOT EXISTS idx_apoderados_dni ON apoderados(dni);

-- =============================================================
-- DATOS SEMILLA (VALETEC DEMO SEED)
-- =============================================================

INSERT INTO roles (id, nombre, descripcion) VALUES 
(1, 'admin', 'Administrador General del Sistema'),
(2, 'supervisor', 'Supervisor de Control de Asistencia'),
(3, 'padre', 'Apoderado / Padre de Familia')
ON CONFLICT (id) DO NOTHING;

-- Usuarios iniciales
INSERT INTO usuarios (id, rol_id, identificador, password_hash, nombre_completo, telefono, correo) VALUES 
(1, 1, 'admin', '12345', 'Administrador General VT', '987000111', 'admin@valetec.pe'),
(2, 3, '45678901', '12345', 'María Torres Salazar', '999888777', 'maria.torres@gmail.com'),
(3, 3, '78901234', '12345', 'Roberto Mendoza Castro', '987654321', 'roberto.m@gmail.com')
ON CONFLICT (id) DO NOTHING;

-- Grados / Grupos / Ciclos
INSERT INTO grados_secciones (id, nivel, grado, seccion, hora_ingreso, tolerancia_minutos, hora_limite_tardanza) VALUES 
(1, 'Secundaria / Nivel II', '3er Grado / Aula 301', 'A', '07:30:00', 15, '08:15:00'),
(2, 'Primaria / Nivel I', '5to Grado / Aula 204', 'B', '07:45:00', 15, '08:30:00'),
(3, 'Pre-Universitario', 'Ciclo Intensivo', 'U', '07:30:00', 15, '08:15:00'),
(4, 'Primaria / Nivel I', '1er Grado / Aula 102', 'A', '07:45:00', 15, '08:30:00')
ON CONFLICT (id) DO NOTHING;

-- Apoderados
INSERT INTO apoderados (id, usuario_id, dni, nombres_completos, telefono_whatsapp, correo, direccion) VALUES 
(1, 2, '45678901', 'María Torres Salazar', '999888777', 'maria.torres@gmail.com', 'Calle Los Pinos 456, Centro'),
(2, 3, '78901234', 'Roberto Mendoza Castro', '987654321', 'roberto.m@gmail.com', 'Av. Las Flores 123, Urb. San Carlos')
ON CONFLICT (id) DO NOTHING;

-- Estudiantes con DNI
INSERT INTO estudiantes (id, dni, codigo_estudiante, pin_biometrico, nombres, apellidos, grado_seccion_id) VALUES 
(1, '72114455', 'VT-1001', '101', 'Carlos', 'Mendoza Ruiz', 1),
(2, '73225566', 'VT-1002', '102', 'Lucía', 'Gómez Torres', 1),
(3, '74336677', 'VT-1003', '103', 'Mateo', 'Gómez Torres', 2),
(4, '75447788', 'VT-1004', '104', 'Sofía', 'Castro Díaz', 3),
(5, '76558899', 'VT-1005', '105', 'Diego', 'Ramos Vega', 4)
ON CONFLICT (id) DO NOTHING;

-- Relación Familia Gómez Torres
INSERT INTO estudiante_apoderado (estudiante_id, apoderado_id, parentesco) VALUES 
(2, 1, 'Madre'),
(3, 1, 'Madre'),
(1, 2, 'Padre')
ON CONFLICT DO NOTHING;
