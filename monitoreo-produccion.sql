
CREATE EXTENSION IF NOT EXISTS postgis;


DROP TABLE IF EXISTS alarmas CASCADE;
DROP TABLE IF EXISTS lecturas CASCADE;
DROP TABLE IF EXISTS empleado_turno CASCADE;
DROP TABLE IF EXISTS filtros CASCADE;
DROP TABLE IF EXISTS sensores CASCADE;
DROP TABLE IF EXISTS microcontroladores CASCADE;
DROP TABLE IF EXISTS empleados CASCADE;
DROP TABLE IF EXISTS turnos CASCADE;
DROP TABLE IF EXISTS productos CASCADE;
DROP TABLE IF EXISTS tipos_filtro CASCADE;
DROP TABLE IF EXISTS lineas_produccion CASCADE;
DROP TABLE IF EXISTS clasificacion_ppm CASCADE;
DROP TABLE IF EXISTS fabricas CASCADE;

DROP FUNCTION IF EXISTS fn_clasificar_ppm(NUMERIC);
DROP FUNCTION IF EXISTS fn_asignar_clasificacion_lectura();

-- Tabla: fabricas

CREATE TABLE fabricas (
    id_fabrica      CHAR(1) PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL,
    ciudad          VARCHAR(80),
    ubicacion       GEOGRAPHY(POINT, 4326),
    activa          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE fabricas IS 'Tres plantas: A, B y C';


-- Tabla: lineas_produccion 

CREATE TABLE lineas_produccion (
    id_linea        VARCHAR(5) PRIMARY KEY,
    id_fabrica      CHAR(1) NOT NULL REFERENCES fabricas(id_fabrica),
    nombre          VARCHAR(80) NOT NULL,
    activa          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_lineas_fabrica ON lineas_produccion(id_fabrica);


-- Tabla: clasificacion_ppm (Anexo A)

CREATE TABLE clasificacion_ppm (
    id_clasificacion SERIAL PRIMARY KEY,
    ppm_min          NUMERIC(12, 4) NOT NULL,
    ppm_max          NUMERIC(12, 4) NOT NULL,
    nivel            VARCHAR(80) NOT NULL,
    impacto_salud    TEXT,
    protocolo        TEXT NOT NULL,
    color_led        VARCHAR(30),
    CONSTRAINT chk_ppm_rango CHECK (ppm_max > ppm_min)
);

COMMENT ON TABLE clasificacion_ppm IS 'Clasificación de peligrosidad según Anexo A - Benceno';

-- Tabla: productos químicos

CREATE TABLE productos (
    id_producto     SERIAL PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL,
    descripcion     TEXT,
    emite_benceno   BOOLEAN NOT NULL DEFAULT TRUE,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);


-- Tabla: tipos de filtro

CREATE TABLE tipos_filtro (
    id_tipo_filtro  SERIAL PRIMARY KEY,
    descripcion     VARCHAR(120) NOT NULL,
    costo_usd       NUMERIC(10, 2) NOT NULL DEFAULT 300.00,
    vida_max_dias   INTEGER NOT NULL DEFAULT 15,
    proveedor       VARCHAR(120)
);

COMMENT ON COLUMN tipos_filtro.costo_usd IS 'Costo aproximado USD 300 según caso de estudio';


-- Tabla: microcontroladores (ESP8266)

CREATE TABLE microcontroladores (
    id_micro        VARCHAR(10) PRIMARY KEY,
    id_linea        VARCHAR(5) NOT NULL REFERENCES lineas_produccion(id_linea),
    modelo          VARCHAR(40) NOT NULL DEFAULT 'ESP8266',
    tiene_wifi      BOOLEAN NOT NULL DEFAULT TRUE,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);


-- Tabla: sensores MQ-135 (benceno)

CREATE TABLE sensores (
    id_sensor       VARCHAR(10) PRIMARY KEY,
    id_micro        VARCHAR(10) NOT NULL REFERENCES microcontroladores(id_micro),
    id_linea        VARCHAR(5) NOT NULL REFERENCES lineas_produccion(id_linea),
    tipo_sensor     VARCHAR(40) NOT NULL DEFAULT 'MQ-135',
    fecha_calibracion DATE,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_sensores_linea ON sensores(id_linea);


-- Tabla: filtros instalados por línea

CREATE TABLE filtros (
    id_filtro           SERIAL PRIMARY KEY,
    id_linea            VARCHAR(5) NOT NULL REFERENCES lineas_produccion(id_linea),
    id_tipo_filtro      INTEGER NOT NULL REFERENCES tipos_filtro(id_tipo_filtro),
    fecha_instalacion   DATE NOT NULL,
    fecha_cambio        DATE,
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    observaciones       TEXT
);


-- Tabla: turnos (3 turnos de 8 horas)

CREATE TABLE turnos (
    id_turno        INTEGER PRIMARY KEY,
    nombre          VARCHAR(40) NOT NULL,
    hora_inicio     TIME NOT NULL,
    hora_fin        TIME NOT NULL,
    descripcion     VARCHAR(120)
);


-- Tabla: empleados

CREATE TABLE empleados (
    id_empleado     SERIAL PRIMARY KEY,
    documento       VARCHAR(20) UNIQUE,
    nombre          VARCHAR(120) NOT NULL,
    cargo           VARCHAR(80),
    id_fabrica      CHAR(1) REFERENCES fabricas(id_fabrica),
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);


-- Tabla: empleado_turno (supervisor y trabajadores por turno)

CREATE TABLE empleado_turno (
    id              SERIAL PRIMARY KEY,
    id_empleado     INTEGER NOT NULL REFERENCES empleados(id_empleado),
    id_turno        INTEGER NOT NULL REFERENCES turnos(id_turno),
    id_fabrica      CHAR(1) NOT NULL REFERENCES fabricas(id_fabrica),
    fecha           DATE NOT NULL,
    es_supervisor   BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (id_empleado, id_turno, id_fabrica, fecha)
);


-- Tabla: lecturas (núcleo del monitoreo - Big Data)

CREATE TABLE lecturas (
    id_lectura          BIGSERIAL PRIMARY KEY,
    ppm_benceno         NUMERIC(10, 4) NOT NULL,
    fecha               DATE NOT NULL,
    hora                TIME NOT NULL,
    id_sensor           VARCHAR(10) NOT NULL REFERENCES sensores(id_sensor),
    id_linea            VARCHAR(5) NOT NULL REFERENCES lineas_produccion(id_linea),
    id_fabrica          CHAR(1) NOT NULL REFERENCES fabricas(id_fabrica),
    latitud             NUMERIC(10, 6),
    longitud            NUMERIC(10, 6),
    altitud             NUMERIC(8, 2),
    ubicacion           GEOGRAPHY(POINT, 4326),
    id_clasificacion    INTEGER REFERENCES clasificacion_ppm(id_clasificacion),
    id_turno            INTEGER REFERENCES turnos(id_turno),
    origen              VARCHAR(20) DEFAULT 'sensor',  -- sensor | excel | api
    fecha_carga         TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ppm_no_negativo CHECK (ppm_benceno >= 0)
);

CREATE INDEX idx_lecturas_fecha       ON lecturas(fecha DESC);
CREATE INDEX idx_lecturas_fabrica     ON lecturas(id_fabrica, fecha DESC);
CREATE INDEX idx_lecturas_sensor      ON lecturas(id_sensor, fecha DESC);
CREATE INDEX idx_lecturas_clasificacion ON lecturas(id_clasificacion);
CREATE INDEX idx_lecturas_timestamp   ON lecturas(fecha, hora);

COMMENT ON TABLE lecturas IS 'Registro de ppm de benceno - 1 lectura cada 10 segundos por sensor';


-- Tabla: alarmas generadas

CREATE TABLE alarmas (
    id_alarma           BIGSERIAL PRIMARY KEY,
    id_lectura          BIGINT REFERENCES lecturas(id_lectura),
    id_fabrica          CHAR(1) NOT NULL REFERENCES fabricas(id_fabrica),
    id_linea            VARCHAR(5) REFERENCES lineas_produccion(id_linea),
    id_clasificacion    INTEGER NOT NULL REFERENCES clasificacion_ppm(id_clasificacion),
    ppm_benceno         NUMERIC(10, 4) NOT NULL,
    protocolo_ejecutado TEXT NOT NULL,
    atendida            BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_alarma        TIMESTAMP NOT NULL DEFAULT NOW()
);


-- Función: clasificar ppm según Anexo A

CREATE OR REPLACE FUNCTION fn_clasificar_ppm(p_ppm NUMERIC)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT id_clasificacion
    FROM clasificacion_ppm
    WHERE p_ppm >= ppm_min AND p_ppm < ppm_max
    ORDER BY ppm_min DESC
    LIMIT 1;
$$;


-- Trigger: asignar clasificación y punto geográfico al insertar lectura

CREATE OR REPLACE FUNCTION fn_asignar_clasificacion_lectura()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id_clasificacion IS NULL THEN
        NEW.id_clasificacion := fn_clasificar_ppm(NEW.ppm_benceno);
    END IF;

    IF NEW.ubicacion IS NULL AND NEW.latitud IS NOT NULL AND NEW.longitud IS NOT NULL THEN
        NEW.ubicacion := ST_SetSRID(ST_MakePoint(NEW.longitud, NEW.latitud), 4326)::geography;
    END IF;

    IF NEW.id_turno IS NULL THEN
        NEW.id_turno := CASE
            WHEN NEW.hora >= TIME '08:00' AND NEW.hora < TIME '16:00' THEN 1
            WHEN NEW.hora >= TIME '16:00' AND NEW.hora < TIME '24:00' THEN 2
            ELSE 3
        END;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lecturas_clasificar
    BEFORE INSERT ON lecturas
    FOR EACH ROW
    EXECUTE PROCEDURE fn_asignar_clasificacion_lectura();


-- Trigger: generar alarma si ppm >= 1 (toxicidad moderada o superior)

CREATE OR REPLACE FUNCTION fn_generar_alarma()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_protocolo TEXT;
BEGIN
    IF NEW.ppm_benceno >= 1.0 AND NEW.id_clasificacion IS NOT NULL THEN
        SELECT protocolo INTO v_protocolo
        FROM clasificacion_ppm
        WHERE id_clasificacion = NEW.id_clasificacion;

        INSERT INTO alarmas (
            id_lectura, id_fabrica, id_linea,
            id_clasificacion, ppm_benceno, protocolo_ejecutado
        ) VALUES (
            NEW.id_lectura, NEW.id_fabrica, NEW.id_linea,
            NEW.id_clasificacion, NEW.ppm_benceno, v_protocolo
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lecturas_alarma
    AFTER INSERT ON lecturas
    FOR EACH ROW
    EXECUTE PROCEDURE fn_generar_alarma();


-- POBLAMIENTO DE DATOS


-- Fábricas
INSERT INTO fabricas (id_fabrica, nombre, ciudad, ubicacion) VALUES
('A', 'Fábrica A - Sustancias Locas', 'Medellín',
 ST_SetSRID(ST_MakePoint(-75.581211, 6.244203), 4326)::geography),
('B', 'Fábrica B - Sustancias Locas', 'Medellín',
 ST_SetSRID(ST_MakePoint(-75.590000, 6.250000), 4326)::geography),
('C', 'Fábrica C - Sustancias Locas', 'Bello',
 ST_SetSRID(ST_MakePoint(-75.557952, 6.336974), 4326)::geography);

-- Líneas de producción 
INSERT INTO lineas_produccion (id_linea, id_fabrica, nombre) VALUES
('A1', 'A', 'Línea producción A1'),
('A2', 'A', 'Línea producción A2'),
('A3', 'A', 'Línea producción A3'),
('A4', 'A', 'Línea producción A4'),
('B1', 'B', 'Línea producción B1'),
('B2', 'B', 'Línea producción B2'),
('B3', 'B', 'Línea producción B3'),
('B4', 'B', 'Línea producción B4'),
('C1', 'C', 'Línea producción C1'),
('C2', 'C', 'Línea producción C2'),
('C3', 'C', 'Línea producción C3'),
('C4', 'C', 'Línea producción C4');

-- Clasificación Anexo A
INSERT INTO clasificacion_ppm (ppm_min, ppm_max, nivel, impacto_salud, protocolo, color_led) VALUES
(0.0000,  0.5000, 'Sin consecuencias',       'Seguro NIOSH largo plazo',                    'Monitoreo normal',                          'VERDE'),
(0.5000,  1.0000, 'Exposición permitida OSHA','Riesgo acumulativo bajo',                     'Registro y vigilancia en turno',             'VERDE'),
(1.0000, 10.0000, 'Toxicidad moderada',       'Anemia, mareo; riesgo cáncer prolongado',   'Revisar microcontrolador y sensor',         'AMARILLO'),
(10.0000, 50.0000, 'Peligroso',               'Náusea, daño orgánico y hematológico',      'DETENER línea de producción',               'NARANJA'),
(50.0000, 500.0000,'Altamente peligroso',     'Pérdida de conciencia, daño nervioso',      'DETENER fábrica completa',                  'ROJO'),
(500.0000, 999999.0000, 'Extremo (letal)',    'Colapso, falla respiratoria, riesgo muerte', 'Llamar Bomberos y Defensa Civil',          'ROJO_PARPADEO');

-- Producto químico principal del caso
INSERT INTO productos (nombre, descripcion, emite_benceno) VALUES
('Producto químico tóxico principal', 'Emite benceno y gases altamente tóxicos durante producción', TRUE);

-- Tipos de filtro
INSERT INTO tipos_filtro (descripcion, costo_usd, vida_max_dias, proveedor) VALUES
('Filtro carbón activo - retención benceno', 300.00, 15, 'Proveedor certificado filtros industriales'),
('Filtro HEPA complementario', 180.00, 30, 'Proveedor certificado filtros industriales');

-- Turnos
INSERT INTO turnos (id_turno, nombre, hora_inicio, hora_fin, descripcion) VALUES
(1, 'Turno 1', '08:00', '16:00', 'Mañana: 8am - 4pm'),
(2, 'Turno 2', '16:00', '00:00', 'Tarde-noche: 4pm - 12am'),
(3, 'Turno 3', '00:00', '08:00', 'Madrugada: 12am - 8am');

-- Empleados de ejemplo
INSERT INTO empleados (documento, nombre, cargo, id_fabrica) VALUES
('1001', 'Carlos Méndez',    'Supervisor de planta', 'A'),
('1002', 'Ana Rodríguez',    'Operario línea',       'A'),
('1003', 'Luis Gómez',       'Supervisor de planta', 'B'),
('1004', 'María López',      'Técnico HSE',          'C');

INSERT INTO empleado_turno (id_empleado, id_turno, id_fabrica, fecha, es_supervisor) VALUES
(1, 1, 'A', CURRENT_DATE, TRUE),
(2, 1, 'A', CURRENT_DATE, FALSE),
(3, 2, 'B', CURRENT_DATE, TRUE),
(4, 3, 'C', CURRENT_DATE, TRUE);

-- Microcontroladores y sensores (muestra línea A1: A1M01-A1M05, A1S01-A1S05)
INSERT INTO microcontroladores (id_micro, id_linea) VALUES
('A1M01', 'A1'), ('A1M02', 'A1'), ('A1M03', 'A1'),
('B1M01', 'B1'), ('C1M01', 'C1');

INSERT INTO sensores (id_sensor, id_micro, id_linea, fecha_calibracion) VALUES
('A1S01', 'A1M01', 'A1', CURRENT_DATE - 30),
('A1S02', 'A1M02', 'A1', CURRENT_DATE - 30),
('A1S03', 'A1M03', 'A1', CURRENT_DATE - 15),
('B1S01', 'B1M01', 'B1', CURRENT_DATE - 20),
('C1S01', 'C1M01', 'C1', CURRENT_DATE - 10);

-- Filtros activos
INSERT INTO filtros (id_linea, id_tipo_filtro, fecha_instalacion, activo) VALUES
('A1', 1, CURRENT_DATE - 8,  TRUE),
('A2', 1, CURRENT_DATE - 6,  TRUE),
('B1', 1, CURRENT_DATE - 12, TRUE),
('C1', 1, CURRENT_DATE - 5,  TRUE);

-- Lecturas de ejemplo (simulan API HTTP desde ESP8266)
INSERT INTO lecturas (
    ppm_benceno, fecha, hora, id_sensor, id_linea, id_fabrica,
    latitud, longitud, altitud, origen
) VALUES
(0.35, CURRENT_DATE, '08:00:10', 'A1S01', 'A1', 'A', 6.244203, -75.581211, 1500.0, 'sensor'),
(0.72, CURRENT_DATE, '08:00:20', 'A1S02', 'A1', 'A', 6.244210, -75.581220, 1500.0, 'sensor'),
(1.25, CURRENT_DATE, '10:15:30', 'A1S03', 'A1', 'A', 6.244215, -75.581225, 1500.0, 'sensor'),
(0.48, CURRENT_DATE, '14:30:00', 'B1S01', 'B1', 'B', 6.250000, -75.590000, 1520.0, 'sensor'),
(2.10, CURRENT_DATE, '16:45:00', 'B1S01', 'B1', 'B', 6.250005, -75.590010, 1520.0, 'sensor'),
(0.90, CURRENT_DATE, '22:10:00', 'C1S01', 'C1', 'C', 6.336974, -75.557952, 1480.0, 'sensor'),
(11.5, CURRENT_DATE - 1, '09:00:00', 'A1S01', 'A1', 'A', 6.244203, -75.581211, 1500.0, 'sensor'),
(0.55, CURRENT_DATE, '08:00:10', 'A1S01', 'A1', 'A', 6.244203, -75.581211, 1500.0, 'excel');


-- VISTAS ÚTILES PARA METABASE / QUICKSIGHT

CREATE OR REPLACE VIEW vw_promedio_ppm_fabrica_3dias AS
SELECT
    l.id_fabrica,
    f.nombre AS nombre_fabrica,
    l.fecha,
    ROUND(AVG(l.ppm_benceno)::numeric, 4) AS ppm_promedio
FROM lecturas l
JOIN fabricas f ON f.id_fabrica = l.id_fabrica
WHERE l.fecha >= CURRENT_DATE - INTERVAL '3 days'
GROUP BY l.id_fabrica, f.nombre, l.fecha
ORDER BY l.id_fabrica, l.fecha;

CREATE OR REPLACE VIEW vw_alarmas_activas AS
SELECT
    a.id_alarma,
    a.id_fabrica,
    a.id_linea,
    c.nivel,
    a.ppm_benceno,
    a.protocolo_ejecutado,
    a.fecha_alarma
FROM alarmas a
JOIN clasificacion_ppm c ON c.id_clasificacion = a.id_clasificacion
WHERE a.atendida = FALSE
ORDER BY a.fecha_alarma DESC;

CREATE OR REPLACE VIEW vw_frecuencia_clasificacion AS
SELECT
    c.nivel,
    c.color_led,
    COUNT(*) AS frecuencia
FROM lecturas l
JOIN clasificacion_ppm c ON c.id_clasificacion = l.id_clasificacion
GROUP BY c.id_clasificacion, c.nivel, c.color_led
ORDER BY c.id_clasificacion;

CREATE OR REPLACE VIEW vw_filtros AS
SELECT
    f.*,
    (COALESCE(f.fecha_cambio, CURRENT_DATE) - f.fecha_instalacion) AS dias_en_uso
FROM filtros f;

-- CONSULTAS DE VERIFICACIÓN
-- SELECT * FROM fabricas;
-- SELECT * FROM clasificacion_ppm;
-- SELECT * FROM lecturas ORDER BY id_lectura DESC LIMIT 10;
-- SELECT * FROM alarmas;
-- SELECT * FROM vw_promedio_ppm_fabrica_3dias;
-- SELECT fn_clasificar_ppm(12.5);  -- Debe retornar id clasificación "Peligroso"

SELECT * FROM fabricas;
SELECT COUNT(*) AS total_lecturas FROM lecturas;
SELECT * FROM alarmas;
SELECT * FROM clasificacion_ppm;
SELECT id_filtro, id_linea, dias_en_uso FROM vw_filtros;


SELECT 'fabricas' AS tabla, COUNT(*) FROM fabricas
UNION ALL SELECT 'lecturas', COUNT(*) FROM lecturas
UNION ALL SELECT 'alarmas', COUNT(*) FROM alarmas;