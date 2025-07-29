-- Entrega final Curso SQL Coderhouse Emmanuel Miranda--

DROP DATABASE IF EXISTS hoteleria;
CREATE DATABASE hoteleria;
USE hoteleria;


CREATE TABLE pais (
    id_pais INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE categoria_hotel (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(50)
);

CREATE TABLE hotel (
    id_hotel INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    ciudad VARCHAR(100),
    id_pais INT,
    id_categoria INT,
    marca VARCHAR(100),
    FOREIGN KEY (id_pais) REFERENCES pais(id_pais),
    FOREIGN KEY (id_categoria) REFERENCES categoria_hotel(id_categoria)
);

CREATE TABLE usuario (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100),
    email VARCHAR(100)
);

CREATE TABLE tipo_reporte (
    id_tipo INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(50)
);

CREATE TABLE reporte (
    id_reporte INT AUTO_INCREMENT PRIMARY KEY,
    id_hotel INT NOT NULL,
    fecha DATE NOT NULL,
    tipo_reporte VARCHAR(50),
    id_tipo INT,
    id_usuario INT,
    FOREIGN KEY (id_hotel) REFERENCES hotel(id_hotel),
    FOREIGN KEY (id_tipo) REFERENCES tipo_reporte(id_tipo),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);

CREATE TABLE indicador (
    id_indicador INT AUTO_INCREMENT PRIMARY KEY,
    id_reporte INT NOT NULL,
    total_habitaciones INT,
    habitaciones_ocupadas INT,
    uso_interno INT,
    personas_alojadas INT,
    adr DECIMAL(10,2),
    FOREIGN KEY (id_reporte) REFERENCES reporte(id_reporte)
);

CREATE TABLE venta (
    id_venta INT AUTO_INCREMENT PRIMARY KEY,
    id_reporte INT NOT NULL,
    ingresos_habitaciones DECIMAL(10,2),
    ingresos_alimentos_bebidas DECIMAL(10,2),
    otros_ingresos DECIMAL(10,2),
    FOREIGN KEY (id_reporte) REFERENCES reporte(id_reporte)
);

CREATE TABLE habitacion (
    id_habitacion INT AUTO_INCREMENT PRIMARY KEY,
    id_hotel INT,
    numero VARCHAR(10),
    tipo VARCHAR(50),
    precio DECIMAL(10,2),
    FOREIGN KEY (id_hotel) REFERENCES hotel(id_hotel)
);

CREATE TABLE reserva (
    id_reserva INT AUTO_INCREMENT PRIMARY KEY,
    id_habitacion INT,
    id_usuario INT,
    fecha_inicio DATE,
    fecha_fin DATE,
    FOREIGN KEY (id_habitacion) REFERENCES habitacion(id_habitacion),
    FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);

CREATE TABLE servicio_extra (
    id_servicio INT AUTO_INCREMENT PRIMARY KEY,
    descripcion VARCHAR(100),
    precio DECIMAL(10,2)
);

CREATE TABLE detalle_servicio (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_reserva INT,
    id_servicio INT,
    cantidad INT,
    FOREIGN KEY (id_reserva) REFERENCES reserva(id_reserva),
    FOREIGN KEY (id_servicio) REFERENCES servicio_extra(id_servicio)
);

CREATE TABLE log_actualizaciones_indicador (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_indicador INT,
    campo_modificado VARCHAR(50),
    valor_anterior VARCHAR(100),
    valor_nuevo VARCHAR(100),
    fecha_hora DATETIME,
    FOREIGN KEY (id_indicador) REFERENCES indicador(id_indicador)
);

CREATE TABLE log_insert_reporte (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    fecha_evento DATETIME,
    id_hotel INT,
    mensaje VARCHAR(255)
);

CREATE TABLE log_errores (
    id_error INT AUTO_INCREMENT PRIMARY KEY,
    tabla VARCHAR(50),
    descripcion VARCHAR(255),
    fecha_hora DATETIME
);

DELIMITER $$

CREATE FUNCTION calcular_revpar(adr DECIMAL(10,2), ocupacion DECIMAL(5,2))
RETURNS DECIMAL(10,2) DETERMINISTIC
BEGIN
    RETURN ROUND(adr * ocupacion, 2);
END$$

CREATE FUNCTION fn_nivel_ocupacion(hab_ocupadas INT, total_hab INT)
RETURNS VARCHAR(50) DETERMINISTIC
BEGIN
    DECLARE p DECIMAL(5,2);
    IF total_hab = 0 THEN RETURN 'ocupación no disponible'; END IF;
    SET p = (hab_ocupadas / total_hab) * 100;
    IF p < 50 THEN RETURN 'ocupación baja';
    ELSEIF p <= 65 THEN RETURN 'ocupación media';
    ELSE RETURN 'ocupación alta';
    END IF;
END$$

CREATE FUNCTION fn_promedio_personas(reporte_id INT)
RETURNS DECIMAL(5,2) DETERMINISTIC
BEGIN
    DECLARE prom DECIMAL(5,2);
    SELECT AVG(personas_alojadas) INTO prom FROM indicador WHERE id_reporte = reporte_id;
    RETURN prom;
END$$

CREATE PROCEDURE insertar_reporte_completo(
    IN p_id_hotel INT, IN p_fecha DATE, IN p_tipo VARCHAR(50),
    IN p_total INT, IN p_ocupadas INT, IN p_uso INT, IN p_personas INT, IN p_adr DECIMAL(10,2),
    IN p_ing_hab DECIMAL(10,2), IN p_ing_ab DECIMAL(10,2), IN p_otros DECIMAL(10,2)
)
BEGIN
    DECLARE nuevo_id INT;
    INSERT INTO reporte (id_hotel, fecha, tipo_reporte) VALUES (p_id_hotel, p_fecha, p_tipo);
    SET nuevo_id = LAST_INSERT_ID();
    INSERT INTO indicador (id_reporte, total_habitaciones, habitaciones_ocupadas, uso_interno, personas_alojadas, adr)
    VALUES (nuevo_id, p_total, p_ocupadas, p_uso, p_personas, p_adr);
    INSERT INTO venta (id_reporte, ingresos_habitaciones, ingresos_alimentos_bebidas, otros_ingresos)
    VALUES (nuevo_id, p_ing_hab, p_ing_ab, p_otros);
END$$

CREATE PROCEDURE sp_insertar_hotel_completo(
    IN p_nombre VARCHAR(100), IN p_ciudad VARCHAR(100), IN p_pais INT, IN p_categoria INT, IN p_marca VARCHAR(100)
)
BEGIN
    INSERT INTO hotel (nombre, ciudad, id_pais, id_categoria, marca) VALUES (p_nombre, p_ciudad, p_pais, p_categoria, p_marca);
END$$

CREATE PROCEDURE sp_registrar_reserva(
    IN p_habitacion INT, IN p_usuario INT, IN p_inicio DATE, IN p_fin DATE
)
BEGIN
    INSERT INTO reserva (id_habitacion, id_usuario, fecha_inicio, fecha_fin)
    VALUES (p_habitacion, p_usuario, p_inicio, p_fin);
END$$


CREATE TRIGGER before_insert_reporte_log
BEFORE INSERT ON reporte
FOR EACH ROW
BEGIN
    INSERT INTO log_insert_reporte (fecha_evento, id_hotel, mensaje)
    VALUES (NOW(), NEW.id_hotel, CONCAT('Nuevo reporte creado para hotel ID ', NEW.id_hotel));
END$$

CREATE TRIGGER tr_after_update_indicador
AFTER UPDATE ON indicador
FOR EACH ROW
BEGIN
    IF OLD.habitaciones_ocupadas <> NEW.habitaciones_ocupadas THEN
        INSERT INTO log_actualizaciones_indicador (id_indicador, campo_modificado, valor_anterior, valor_nuevo, fecha_hora)
        VALUES (OLD.id_indicador, 'habitaciones_ocupadas', OLD.habitaciones_ocupadas, NEW.habitaciones_ocupadas, NOW());
    END IF;
END$$

CREATE TRIGGER tr_log_reserva
AFTER INSERT ON reserva
FOR EACH ROW
BEGIN
    IF NEW.fecha_fin < NEW.fecha_inicio THEN
        INSERT INTO log_errores (tabla, descripcion, fecha_hora)
        VALUES ('reserva', 'Fecha de fin menor a fecha de inicio', NOW());
    END IF;
END$$

DELIMITER ;

CREATE VIEW vista_metrica AS
SELECT i.id_indicador, i.id_reporte,
       ROUND(i.habitaciones_ocupadas / i.total_habitaciones, 4) AS porcentaje_ocupacion,
       ROUND(i.personas_alojadas / i.habitaciones_ocupadas, 2) AS doble_ocupacion,
       calcular_revpar(i.adr, (i.habitaciones_ocupadas / i.total_habitaciones)) AS revpar
FROM indicador i;

CREATE VIEW vw_ocupacion_diaria AS
SELECT h.nombre, r.fecha,
       ROUND(i.habitaciones_ocupadas / i.total_habitaciones, 2) AS ocupacion
FROM hotel h
JOIN reporte r ON h.id_hotel = r.id_hotel
JOIN indicador i ON r.id_reporte = i.id_reporte;

-- DATOS DE EJEMPLO

INSERT INTO pais (nombre) VALUES ('Argentina'), ('Chile'), ('Brasil'), ('Uruguay'), ('Perú');
INSERT INTO categoria_hotel (descripcion) VALUES ('3 Estrellas'), ('4 Estrellas'), ('5 Estrellas');
INSERT INTO usuario (nombre, email) VALUES ('Ana Suárez','ana@bi.com'),('Luis Pérez','luis@hotel.com'),
('Mariana Gómez','mariana@dash.com'),('Carlos López','carlos@admin.com'),('Lucía Fernández','lucia@data.com');
INSERT INTO tipo_reporte (descripcion) VALUES ('Flash'), ('Diario'), ('Manager');
INSERT INTO hotel (nombre, ciudad, id_pais, id_categoria, marca) VALUES 
('Marriott Buenos Aires','Buenos Aires',1,3,'Marriott'),
('Sheraton Santiago','Santiago',2,3,'Sheraton'),
('Hilton Rio','Rio de Janeiro',3,3,'Hilton');

-- Ejemplos habitacion, reporte, indicador, venta, reserva, etc.
