
SELECT 'fabricas' AS tabla, COUNT(*)::bigint AS total FROM fabricas
UNION ALL SELECT 'lineas_produccion', COUNT(*) FROM lineas_produccion
UNION ALL SELECT 'clasificacion_ppm', COUNT(*) FROM clasificacion_ppm
UNION ALL SELECT 'sensores', COUNT(*) FROM sensores
UNION ALL SELECT 'lecturas', COUNT(*) FROM lecturas
UNION ALL SELECT 'alarmas', COUNT(*) FROM alarmas;

-- ---------------------------------------------------------------------------
-- 2) FÁBRICAS 
SELECT id_fabrica, nombre, ciudad, activa
FROM fabricas
ORDER BY id_fabrica;

-- ---------------------------------------------------------------------------
-- 3) LÍNEAS DE PRODUCCIÓN

SELECT l.id_linea, l.id_fabrica, f.nombre AS fabrica, l.nombre AS linea
FROM lineas_produccion l
JOIN fabricas f ON f.id_fabrica = l.id_fabrica
ORDER BY l.id_fabrica, l.id_linea;

-- ---------------------------------------------------------------------------
-- 4) CLASIFICACIÓN PPM 
SELECT id_clasificacion, ppm_min, ppm_max, nivel, protocolo, color_led
FROM clasificacion_ppm
ORDER BY ppm_min;

-- ---------------------------------------------------------------------------
-- 5) SENSORES Y MICROCONTROLADORES
SELECT s.id_sensor, s.id_micro, s.id_linea, s.tipo_sensor, s.fecha_calibracion
FROM sensores s
ORDER BY s.id_sensor;

-- ---------------------------------------------------------------------------
-- 6) LECTURAS
SELECT
    id_lectura,
    ppm_benceno,
    fecha,
    hora,
    id_sensor,
    id_linea,
    id_fabrica,
    id_clasificacion,
    id_turno,
    origen
FROM lecturas
ORDER BY id_lectura;

-- ---------------------------------------------------------------------------
-- 7) LECTURAS CON NOMBRE DE CLASIFICACIÓN 
SELECT
    l.id_lectura,
    l.ppm_benceno,
    c.nivel,
    c.protocolo,
    l.id_sensor,
    l.id_fabrica
FROM lecturas l
LEFT JOIN clasificacion_ppm c ON c.id_clasificacion = l.id_clasificacion
ORDER BY l.ppm_benceno DESC;

-- ---------------------------------------------------------------------------
-- 8) GEOLOCALIZACIÓN PostGIS

SELECT
    id_lectura,
    ppm_benceno,
    latitud,
    longitud,
    ST_AsText(ubicacion::geometry) AS punto_postgis
FROM lecturas
ORDER BY id_lectura
LIMIT 5;

-- ---------------------------------------------------------------------------
-- 9) ALARMAS GENERADAS AUTOMÁTICAMENTE
SELECT
    a.id_alarma,
    a.id_lectura,
    a.ppm_benceno,
    c.nivel,
    a.protocolo_ejecutado,
    a.atendida,
    a.fecha_alarma
FROM alarmas a
JOIN clasificacion_ppm c ON c.id_clasificacion = a.id_clasificacion
ORDER BY a.ppm_benceno DESC;

-- ---------------------------------------------------------------------------
-- 10) EMPLEADOS Y TURNOS
SELECT e.id_empleado, e.nombre, e.cargo, e.id_fabrica
FROM empleados e
ORDER BY e.id_empleado;

SELECT t.id_turno, t.nombre, t.hora_inicio, t.hora_fin
FROM turnos t
ORDER BY t.id_turno;

-- ---------------------------------------------------------------------------
-- 11) FILTROS INSTALADOS

SELECT f.id_filtro, f.id_linea, tf.descripcion, tf.costo_usd, f.fecha_instalacion, f.activo
FROM filtros f
JOIN tipos_filtro tf ON tf.id_tipo_filtro = f.id_tipo_filtro
ORDER BY f.id_filtro;


