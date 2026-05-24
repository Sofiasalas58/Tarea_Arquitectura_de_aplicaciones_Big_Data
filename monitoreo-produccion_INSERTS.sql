-- =============================================================================
-- SUSTANCIAS LOCAS - Poblamiento (DML) - Base de datos monitoreo-produccion
-- Sección 7.1 del informe - Ejecutar DESPUÉS de monitoreo-produccion.sql (DDL)
-- =============================================================================

-- Fábricas (3)
INSERT INTO fabricas (id_fabrica, nombre, ciudad, ubicacion) VALUES
('A', 'Fábrica A - Sustancias Locas', 'Medellín',
 ST_SetSRID(ST_MakePoint(-75.581211, 6.244203), 4326)::geography),
('B', 'Fábrica B - Sustancias Locas', 'Medellín',
 ST_SetSRID(ST_MakePoint(-75.590000, 6.250000), 4326)::geography),
('C', 'Fábrica C - Sustancias Locas', 'Bello',
 ST_SetSRID(ST_MakePoint(-75.557952, 6.336974), 4326)::geography);

-- Líneas de producción (12: 4 por fábrica)
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

-- Clasificación ppm - Anexo A (6 niveles)
INSERT INTO clasificacion_ppm (ppm_min, ppm_max, nivel, impacto_salud, protocolo, color_led) VALUES
(0.0000,  0.5000, 'Sin consecuencias',       'Seguro NIOSH largo plazo',                    'Monitoreo normal',                          'VERDE'),
(0.5000,  1.0000, 'Exposición permitida OSHA','Riesgo acumulativo bajo',                     'Registro y vigilancia en turno',             'VERDE'),
(1.0000, 10.0000, 'Toxicidad moderada',       'Anemia, mareo; riesgo cáncer prolongado',   'Revisar microcontrolador y sensor',         'AMARILLO'),
(10.0000, 50.0000, 'Peligroso',               'Náusea, daño orgánico y hematológico',      'DETENER línea de producción',               'NARANJA'),
(50.0000, 500.0000,'Altamente peligroso',     'Pérdida de conciencia, daño nervioso',      'DETENER fábrica completa',                  'ROJO'),
(500.0000, 999999.0000, 'Extremo (letal)',    'Colapso, falla respiratoria, riesgo muerte', 'Llamar Bomberos y Defensa Civil',          'ROJO_PARPADEO');

-- Productos químicos
INSERT INTO productos (nombre, descripcion, emite_benceno) VALUES
('Producto químico tóxico principal', 'Emite benceno y gases altamente tóxicos durante producción', TRUE);

-- Tipos de filtro
INSERT INTO tipos_filtro (descripcion, costo_usd, vida_max_dias, proveedor) VALUES
('Filtro carbón activo - retención benceno', 300.00, 15, 'Proveedor certificado filtros industriales'),
('Filtro HEPA complementario', 180.00, 30, 'Proveedor certificado filtros industriales');

-- Turnos (3 x 8 horas)
INSERT INTO turnos (id_turno, nombre, hora_inicio, hora_fin, descripcion) VALUES
(1, 'Turno 1', '08:00', '16:00', 'Mañana: 8am - 4pm'),
(2, 'Turno 2', '16:00', '00:00', 'Tarde-noche: 4pm - 12am'),
(3, 'Turno 3', '00:00', '08:00', 'Madrugada: 12am - 8am');

-- Empleados
INSERT INTO empleados (documento, nombre, cargo, id_fabrica) VALUES
('1001', 'Carlos Méndez',    'Supervisor de planta', 'A'),
('1002', 'Ana Rodríguez',    'Operario línea',       'A'),
('1003', 'Luis Gómez',       'Supervisor de planta', 'B'),
('1004', 'María López',      'Técnico HSE',          'C');

-- Asignación empleado-turno
INSERT INTO empleado_turno (id_empleado, id_turno, id_fabrica, fecha, es_supervisor) VALUES
(1, 1, 'A', CURRENT_DATE, TRUE),
(2, 1, 'A', CURRENT_DATE, FALSE),
(3, 2, 'B', CURRENT_DATE, TRUE),
(4, 3, 'C', CURRENT_DATE, TRUE);

-- Microcontroladores (muestra)
INSERT INTO microcontroladores (id_micro, id_linea) VALUES
('A1M01', 'A1'), ('A1M02', 'A1'), ('A1M03', 'A1'),
('B1M01', 'B1'), ('C1M01', 'C1');

-- Sensores MQ-135 (muestra)
INSERT INTO sensores (id_sensor, id_micro, id_linea, fecha_calibracion) VALUES
('A1S01', 'A1M01', 'A1', CURRENT_DATE - 30),
('A1S02', 'A1M02', 'A1', CURRENT_DATE - 30),
('A1S03', 'A1M03', 'A1', CURRENT_DATE - 15),
('B1S01', 'B1M01', 'B1', CURRENT_DATE - 20),
('C1S01', 'C1M01', 'C1', CURRENT_DATE - 10);

-- Filtros instalados
INSERT INTO filtros (id_linea, id_tipo_filtro, fecha_instalacion, activo) VALUES
('A1', 1, CURRENT_DATE - 8,  TRUE),
('A2', 1, CURRENT_DATE - 6,  TRUE),
('B1', 1, CURRENT_DATE - 12, TRUE),
('C1', 1, CURRENT_DATE - 5,  TRUE);

-- Lecturas (simulan API HTTP desde ESP8266)
-- Triggers asignan: id_clasificacion, id_turno, ubicacion (PostGIS)
-- Trigger AFTER INSERT genera registros en tabla alarmas si ppm >= 1
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

-- NOTA: La tabla ALARMAS no tiene INSERT manual.
-- Se pobla automáticamente por el trigger trg_lecturas_alarma cuando ppm_benceno >= 1.
