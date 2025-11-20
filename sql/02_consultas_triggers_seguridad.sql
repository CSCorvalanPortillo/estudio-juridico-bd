/******************************************************
 				USUARIOS, ROLES Y PRIVILEGIOS 
******************************************************/

-- Roles del sistema
DROP ROLE IF EXISTS 'rol_editor';
CREATE ROLE 'rol_editor';

DROP ROLE IF EXISTS 'rol_consulta';
CREATE ROLE 'rol_consulta';

-- Privilegios asignados a roles
GRANT SELECT ON estudio_juridico.* TO 'rol_consulta';
GRANT SELECT, INSERT, UPDATE ON estudio_juridico.* TO 'rol_editor';

/*
  NOTA IMPORTANTE:
  Los usuarios locales y las contraseñas NO se incluyen
  por motivos de seguridad. Para asignar roles a usuarios,
  cada instalación deberá crear sus propios usuarios, por ejemplo:

  CREATE USER 'usuario_demo'@'localhost' IDENTIFIED BY 'tu_clave';
  GRANT 'rol_editor' TO 'usuario_demo';
  SET DEFAULT ROLE 'rol_editor' TO 'usuario_demo';
*/


/******************************************************
 				CONSULTAS DE VERIFICACIÓN
******************************************************/

-- 1. Clientes con casos abiertos y su abogado
SELECT
    c.nombre AS Nombre_Cliente,
    c.apellido AS Apellido_Cliente,
    ca.nro_expediente AS Nro_Expediente,
    a.nombre AS Nombre_Abogado_Principal,
    a.apellido AS Apellido_Abogado_Principal
FROM cliente c
JOIN caso ca ON c.id_cliente = ca.id_cliente
JOIN caso_abogado cab ON ca.id_caso = cab.id_caso
JOIN abogado a ON cab.id_abogado = a.id_abogado
WHERE ca.estado = 'Abierto'
ORDER BY c.apellido, ca.nro_expediente;

-- 2. Suma de honorarios pagados por abogado
SELECT
    a.id_abogado,
    CONCAT(a.nombre, ' ', a.apellido) AS abogado,
    SUM(h.monto) AS total_honorarios_pagados
FROM honorario h
JOIN caso c ON h.id_caso = c.id_caso
JOIN caso_abogado ca ON c.id_caso = ca.id_caso 
JOIN abogado a ON ca.id_abogado = a.id_abogado 
WHERE h.estado_pago = 'Pago'
GROUP BY a.id_abogado, a.nombre, a.apellido
ORDER BY total_honorarios_pagados DESC;

-- 3. Deudas por cliente y abogado
SELECT
    c.nombre AS Nombre_Cliente,
    c.apellido AS Apellido_Cliente,
    h.monto AS Monto_Adeudado,
    a.nombre AS Nombre_Abogado,
    a.apellido AS Apellido_Abogado
FROM honorario h
LEFT JOIN caso cas ON h.id_caso = cas.id_caso
LEFT JOIN cliente c ON cas.id_cliente = c.id_cliente
LEFT JOIN caso_abogado ca ON cas.id_caso = ca.id_caso
LEFT JOIN abogado a ON ca.id_abogado = a.id_abogado
WHERE h.estado_pago = 'No pago'
ORDER BY c.apellido, a.apellido;

-- 4. Casos del año 2022
SELECT
    c.nombre AS Nombre_Cliente,
    c.apellido AS Apellido_Cliente,
    cas.estado AS Estado_del_Caso,
    cas.fecha_inicio AS Fecha_Inicio
FROM cliente c
JOIN caso cas ON c.id_cliente = cas.id_cliente
WHERE YEAR(cas.fecha_inicio) = 2022
ORDER BY c.apellido, cas.fecha_inicio ASC;

-- 5. Cantidad de casos cerrados entre 2020 y 2022
SELECT COUNT(*) AS total_casos_cerrados
FROM caso
WHERE estado = 'Cerrado'
  AND YEAR(fecha_cierre) BETWEEN 2020 AND 2022;

-- 6. Abogados con casos abiertos
SELECT DISTINCT
    a.nombre AS Nombre_Abogado,
    a.apellido AS Apellido_Abogado
FROM abogado a
JOIN caso_abogado ca ON a.id_abogado = ca.id_abogado
JOIN caso cas ON ca.id_caso = cas.id_caso
WHERE cas.estado = 'Abierto';

-- 7. Audiencias de noviembre
SELECT *
FROM audiencia
WHERE MONTH(fecha_hora) = 11;


/******************************************************
 				TRIGGERS
******************************************************/

CREATE TABLE IF NOT EXISTS auditoria_caso (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_caso_afectado INT NOT NULL,
    nro_expediente_afectado INT NOT NULL,
    accion VARCHAR(10) NOT NULL,
    fecha_hora DATETIME NOT NULL,
    usuario VARCHAR(100) NOT NULL
);

DELIMITER //

-- 1. Registrar inserciones en CASO
CREATE TRIGGER registrar_cambios
AFTER INSERT ON caso
FOR EACH ROW 
BEGIN
    INSERT INTO auditoria_caso
        (id_caso_afectado, nro_expediente_afectado, accion, fecha_hora, usuario)
    VALUES
        (NEW.id_caso, NEW.nro_expediente, 'INSERT', NOW(), CURRENT_USER());
END //

-- 2. Registrar actualizaciones en CASO
CREATE TRIGGER registrar_actualizacion
AFTER UPDATE ON caso
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_caso
        (id_caso_afectado, nro_expediente_afectado, accion, fecha_hora, usuario)
    VALUES
        (NEW.id_caso, NEW.nro_expediente, 'UPDATE', NOW(), CURRENT_USER());
END //

-- 3. Fecha automática en DOCUMENTO
CREATE TRIGGER fecha_documento_auto
BEFORE INSERT ON documento
FOR EACH ROW
BEGIN
    IF NEW.fecha_carga IS NULL THEN
        SET NEW.fecha_carga = CURDATE();
    END IF;
END //

-- 4–7. Validaciones de mail
CREATE TRIGGER validar_mail_cliente_insert
BEFORE INSERT ON cliente
FOR EACH ROW
BEGIN
    IF NEW.mail NOT LIKE '%@%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El mail del cliente debe contener @';
    END IF;
END //

CREATE TRIGGER validar_mail_cliente_update
BEFORE UPDATE ON cliente
FOR EACH ROW
BEGIN
    IF NEW.mail NOT LIKE '%@%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El mail del cliente debe contener @';
    END IF;
END //

CREATE TRIGGER validar_mail_abogado_insert
BEFORE INSERT ON abogado
FOR EACH ROW
BEGIN
    IF NEW.mail NOT LIKE '%@%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El mail del abogado debe contener @';
    END IF;
END //

CREATE TRIGGER validar_mail_abogado_update
BEFORE UPDATE ON abogado
FOR EACH ROW
BEGIN
    IF NEW.mail NOT LIKE '%@%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El mail del abogado debe contener @';
    END IF;
END //

DELIMITER ;
