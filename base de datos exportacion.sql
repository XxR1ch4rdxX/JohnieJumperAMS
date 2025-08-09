-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 09-08-2025 a las 22:43:21
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `johniejummperams`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `actualizar_estado_cita` (IN `p_cita_id` INT, IN `p_estado_id` INT, IN `p_observaciones` TEXT)   BEGIN
    UPDATE citas 
    SET estado_id = p_estado_id,
        observaciones = CONCAT(IFNULL(observaciones, ''), '\n', p_observaciones)
    WHERE id_cita = p_cita_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `agregar_detalle_pedido` (IN `p_pedido_id` INT, IN `p_producto_id` INT, IN `p_cantidad` INT, IN `p_precio` DECIMAL(10,2))   BEGIN
    INSERT INTO detallespedidos (pedido_id, producto_id, cantidad, precio_unitario)
    VALUES (p_pedido_id, p_producto_id, p_cantidad, p_precio);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `agregar_detalle_venta` (IN `p_venta_id` INT, IN `p_producto_id` INT, IN `p_cantidad` INT)   BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_stock_actual INT;
    
    -- Obtener precio y stock actual
    SELECT precio, stock INTO v_precio, v_stock_actual
    FROM productos 
    WHERE id_producto = p_producto_id;
    
    -- Verificar stock suficiente
    IF p_cantidad > v_stock_actual THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'No hay suficiente stock para este producto';
    ELSE
        -- Registrar detalle de venta
        INSERT INTO detallesventas (venta_id, producto_id, cantidad, precio_unitario)
        VALUES (p_venta_id, p_producto_id, p_cantidad, v_precio);
        
        -- Actualizar stock
        UPDATE productos 
        SET stock = stock - p_cantidad 
        WHERE id_producto = p_producto_id;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `crear_pedido` (IN `p_proveedor_id` INT, IN `p_total` DECIMAL(10,2))   BEGIN
    INSERT INTO pedidos (proveedor_id, fecha, estado_id, total)
    VALUES (p_proveedor_id, NOW(), 1, p_total);
    SELECT LAST_INSERT_ID() as pedido_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `eliminar_producto` (IN `p_id_producto` INT)   BEGIN
    -- Primero eliminar detalles relacionados para evitar errores de clave foránea
    DELETE FROM detallesventas WHERE producto_id = p_id_producto;
    DELETE FROM detallespedidos WHERE producto_id = p_id_producto;
    
    -- Luego eliminar el producto
    DELETE FROM productos WHERE id_producto = p_id_producto;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `filtrar_mas_caros` (IN `limite` INT)   BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.fecha_caducidad,
        cp.nombre AS categoria_nombre,
        pr.nombre AS proveedor_nombre
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    ORDER BY p.precio DESC
    LIMIT limite;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `filtrar_por_categoria` (IN `cat_id` INT)   BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.fecha_caducidad,
        cp.nombre AS categoria,
        pr.nombre AS proveedor
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    WHERE p.categoria_id = cat_id
    ORDER BY p.nombre;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `filtrar_por_fecha_agregado` ()   BEGIN
    SELECT p.*, c.nombre AS categoria_nombre, pr.nombre AS proveedor_nombre
    FROM productos p
    LEFT JOIN categorias_productos c ON p.categoria_id = c.id_categoria
    LEFT JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    ORDER BY p.fecha_agregado DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `filtrar_por_proveedor` (IN `prov_id` INT)   BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.fecha_caducidad,
        cp.nombre AS categoria,
        pr.nombre AS proveedor
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    WHERE p.proveedor_id = prov_id
    ORDER BY p.nombre;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `filtrar_productos_por_nombre` (IN `p_nombre` VARCHAR(255))   BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.fecha_caducidad,
        cp.nombre AS categoria_nombre,
        pr.nombre AS proveedor_nombre
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    WHERE p.nombre LIKE CONCAT('%', p_nombre, '%');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `filtrar_stock_bajo` (IN `cantidad_min` INT)   BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.fecha_caducidad,
        cp.nombre AS categoria,
        pr.nombre AS proveedor
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    WHERE p.stock < cantidad_min
    ORDER BY p.stock ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_categorias` ()   BEGIN
    SELECT id_categoria, nombre FROM categorias_productos ORDER BY nombre;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_estadisticas_dashboard` ()   BEGIN
    -- Citas de hoy
    SELECT COUNT(*) as citas_hoy 
    FROM citas 
    WHERE DATE(fecha) = CURDATE();
    
    -- Ventas del mes
    SELECT IFNULL(SUM(total), 0) as ventas_mes
    FROM ventas 
    WHERE YEAR(fecha) = YEAR(CURDATE()) 
    AND MONTH(fecha) = MONTH(CURDATE());
    
    -- Productos con stock bajo
    SELECT COUNT(*) as productos_stock_bajo
    FROM productos 
    WHERE stock < 10;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_pedidos_pendientes` ()   BEGIN
    SELECT p.id_pedido, pr.nombre as proveedor, p.fecha, p.total,
           e.nombre as estado, COUNT(dp.id_detalle_pedido) as items
    FROM pedidos p
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    LEFT JOIN estatus e ON p.estado_id = e.id_estado
    LEFT JOIN detallespedidos dp ON p.id_pedido = dp.pedido_id
    WHERE p.estado_id IN (1, 2)
    GROUP BY p.id_pedido
    ORDER BY p.fecha DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_productos_detalle` ()   BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.fecha_caducidad,
        cp.nombre AS categoria_nombre,
        pr.nombre AS proveedor_nombre
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    ORDER BY p.nombre;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_productos_venta` (IN `p_busqueda` VARCHAR(100), IN `p_categoria_id` INT, IN `p_proveedor_id` INT)   BEGIN
    SELECT 
        p.id_producto, 
        p.nombre, 
        p.precio, 
        p.stock,
        cp.nombre as categoria,
        pr.nombre as proveedor
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    WHERE p.stock > 0
    AND (p_busqueda IS NULL OR p.nombre LIKE CONCAT('%', p_busqueda, '%'))
    AND (p_categoria_id IS NULL OR p.categoria_id = p_categoria_id)
    AND (p_proveedor_id IS NULL OR p.proveedor_id = p_proveedor_id)
    ORDER BY p.nombre
    LIMIT 50; -- Limitar resultados para mejor rendimiento
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_proveedores` ()   BEGIN
    SELECT id_proveedor, nombre FROM proveedores ORDER BY nombre;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ordenar_por_fecha_caducidad_proxima` ()   BEGIN
    SELECT 
        p.id_producto,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock,
        p.fecha_caducidad,
        cp.nombre AS categoria,
        pr.nombre AS proveedor
    FROM productos p
    JOIN categorias_productos cp ON p.categoria_id = cp.id_categoria
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    WHERE p.fecha_caducidad IS NOT NULL
    ORDER BY p.fecha_caducidad ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `procesar_pedido_recibido` (IN `p_pedido_id` INT)   BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_producto_id INT;
    DECLARE v_cantidad INT;
    
    DECLARE cur CURSOR FOR 
        SELECT producto_id, cantidad 
        FROM detallespedidos 
        WHERE pedido_id = p_pedido_id;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_producto_id, v_cantidad;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        UPDATE productos 
        SET stock = stock + v_cantidad 
        WHERE id_producto = v_producto_id;
    END LOOP;
    CLOSE cur;
    
    -- Marcar pedido como completado
    UPDATE pedidos 
    SET estado_id = 3 
    WHERE id_pedido = p_pedido_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `productos_para_pedido` ()   BEGIN
    SELECT p.id_producto, p.nombre, p.stock, pr.nombre as proveedor,
           pr.id_proveedor, p.precio
    FROM productos p
    JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
    WHERE p.stock < 15
    ORDER BY p.stock ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `registrar_venta_rapida` (IN `p_total` DECIMAL(10,2), OUT `p_venta_id` INT)   BEGIN
    INSERT INTO ventas (fecha, total) 
    VALUES (NOW(), p_total);
    
    SET p_venta_id = LAST_INSERT_ID();
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `animales`
--

CREATE TABLE `animales` (
  `id_animal` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `especie` varchar(50) DEFAULT NULL,
  `raza` varchar(50) DEFAULT NULL,
  `edad` int(11) DEFAULT NULL,
  `cliente_id` int(11) DEFAULT NULL,
  `sexo` varchar(10) DEFAULT NULL,
  `peso` decimal(5,2) DEFAULT NULL,
  `historial_medico` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `animales`
--

INSERT INTO `animales` (`id_animal`, `nombre`, `especie`, `raza`, `edad`, `cliente_id`, `sexo`, `peso`, `historial_medico`) VALUES
(4, 'freson cara blanca', 'caballo', 'frezon', 12, 14, 'Macho', NULL, NULL),
(5, 'freson cara blanca', 'caballos', 'frezon', 12, 15, '', NULL, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `aplicacionesservicio`
--

CREATE TABLE `aplicacionesservicio` (
  `id_aplicacion` bigint(20) UNSIGNED NOT NULL,
  `animal_id` int(11) DEFAULT NULL,
  `servicio_id` int(11) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `observaciones` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `aplicacionesservicio`
--

INSERT INTO `aplicacionesservicio` (`id_aplicacion`, `animal_id`, `servicio_id`, `fecha`, `observaciones`) VALUES
(1, 6, 2, '2025-04-13', 'Responde bien al tratamiento'),
(2, 1, 4, '2025-02-28', 'Requiere seguimiento en 30 días'),
(3, 8, 2, '2025-01-15', 'Leve cojera en pata delantera'),
(4, 3, 6, '2024-08-13', 'Recuperación satisfactoria'),
(5, 7, 5, '2025-01-05', 'Parto sin complicaciones'),
(6, 2, 10, '2025-01-12', 'Prevenir infección con yodo'),
(7, 8, 5, '2025-05-04', 'Sospecha de preñez múltiple'),
(8, 2, 2, '2024-07-21', 'Aplicar pomada antibiótica'),
(9, 5, 3, '2024-09-16', 'Registro de ciclo estral'),
(10, 10, 9, '2025-02-11', 'Fiebre alta - administrar antipirético');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categorias_productos`
--

CREATE TABLE `categorias_productos` (
  `id_categoria` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `categorias_productos`
--

INSERT INTO `categorias_productos` (`id_categoria`, `nombre`) VALUES
(1, 'Alimentos'),
(2, 'Medicamentos'),
(3, 'Suplementos'),
(4, 'Accesorios'),
(5, 'Higiene'),
(6, 'Herramientas'),
(7, 'Semillas'),
(8, 'Forrajes'),
(9, 'Reproducción'),
(10, 'Otros');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `citas`
--

CREATE TABLE `citas` (
  `id_cita` bigint(20) UNSIGNED NOT NULL,
  `cliente_id` int(11) DEFAULT NULL,
  `animal_id` int(11) DEFAULT NULL,
  `servicio_id` int(11) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `estado_id` int(11) DEFAULT NULL,
  `observaciones` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `citas`
--

INSERT INTO `citas` (`id_cita`, `cliente_id`, `animal_id`, `servicio_id`, `fecha`, `estado_id`, `observaciones`) VALUES
(1, 14, 4, 1, '2025-08-09', 1, 'Motivo: consulta general\nObservaciones: el animal camina raro'),
(2, 15, 5, 1, '2025-08-09', 1, 'Motivo: aa\nObservaciones: aa');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clientes`
--

CREATE TABLE `clientes` (
  `id_cliente` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `direccion` varchar(150) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `clientes`
--

INSERT INTO `clientes` (`id_cliente`, `nombre`, `telefono`, `direccion`) VALUES
(1, 'Don Pedro', '555000001', 'Calle Ejido #1'),
(2, 'Martina', '555000002', 'Calle Ejido #2'),
(3, 'Lupita', '555000003', 'Calle Ejido #3'),
(4, 'Doña Rosa', '555000004', 'Calle Ejido #4'),
(5, 'Miguel', '555000005', 'Calle Ejido #5'),
(6, 'Esteban', '555000006', 'Calle Ejido #6'),
(7, 'Carmela', '555000007', 'Calle Ejido #7'),
(8, 'Pancho', '555000008', 'Calle Ejido #8'),
(9, 'Chonita', '555000009', 'Calle Ejido #9'),
(10, 'Eulalio', '555000010', 'Calle Ejido #10'),
(14, 'pancho perez', '3425234534', 'iapusrfoiubajcnpiu'),
(15, 'pancho perez2', '3425234534', 'iapusrfoiubajcnpiu');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `configuraciones`
--

CREATE TABLE `configuraciones` (
  `id_config` bigint(20) UNSIGNED NOT NULL,
  `clave` varchar(50) NOT NULL,
  `valor` text DEFAULT NULL,
  `descripcion` varchar(200) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detallespedidos`
--

CREATE TABLE `detallespedidos` (
  `id_detalle_pedido` bigint(20) UNSIGNED NOT NULL,
  `pedido_id` int(11) DEFAULT NULL,
  `producto_id` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT NULL,
  `precio_unitario` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detallesventas`
--

CREATE TABLE `detallesventas` (
  `id_detalle` bigint(20) UNSIGNED NOT NULL,
  `venta_id` int(11) DEFAULT NULL,
  `producto_id` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT NULL,
  `precio_unitario` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `detallesventas`
--

INSERT INTO `detallesventas` (`id_detalle`, `venta_id`, `producto_id`, `cantidad`, `precio_unitario`) VALUES
(1, 1, 7, 3, 58.76),
(2, 1, 2, 4, 156.75);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estatus`
--

CREATE TABLE `estatus` (
  `id_estado` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `estatus`
--

INSERT INTO `estatus` (`id_estado`, `nombre`) VALUES
(1, 'Pendiente'),
(2, 'Confirmada'),
(3, 'Completada'),
(4, 'Cancelada');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `historialmedico`
--

CREATE TABLE `historialmedico` (
  `id_historial` bigint(20) UNSIGNED NOT NULL,
  `animal_id` int(11) DEFAULT NULL,
  `fecha` date NOT NULL,
  `diagnostico` text DEFAULT NULL,
  `tratamiento` text DEFAULT NULL,
  `notas` text DEFAULT NULL,
  `usuario_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `inventario`
--

CREATE TABLE `inventario` (
  `id_movimiento` bigint(20) UNSIGNED NOT NULL,
  `producto_id` int(11) DEFAULT NULL,
  `tipo_movimiento` varchar(10) DEFAULT NULL,
  `cantidad` int(11) NOT NULL,
  `fecha` date NOT NULL,
  `usuario_id` int(11) DEFAULT NULL,
  `motivo` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

CREATE TABLE `pedidos` (
  `id_pedido` bigint(20) UNSIGNED NOT NULL,
  `proveedor_id` int(11) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `estado_id` int(11) DEFAULT NULL,
  `total` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `id_producto` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `stock` int(11) DEFAULT NULL,
  `fecha_caducidad` date DEFAULT NULL,
  `categoria_id` int(11) DEFAULT NULL,
  `proveedor_id` int(11) DEFAULT NULL,
  `fecha_agregado` date DEFAULT curdate()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id_producto`, `nombre`, `descripcion`, `precio`, `stock`, `fecha_caducidad`, `categoria_id`, `proveedor_id`, `fecha_agregado`) VALUES
(1, 'Maíz Criollo', 'Saco de 20kg para alimentación animal', 11.08, 14, '2025-11-26', 1, 8, '2025-08-07'),
(2, 'Desparasitante Bovino', 'Tratamiento antiparasitario para reses', 156.75, 94, '2025-10-04', 2, 1, '2025-08-03'),
(4, 'Manta Térmica', 'Cobertor para establos en invierno', 181.82, 10, '2026-06-30', 4, 1, '2025-08-01'),
(5, 'Jarabe Expectorante', 'Para problemas respiratorios en cabras', 177.13, 64, '2026-05-28', 2, 1, '2025-08-01'),
(6, 'Pico de Oropel', 'Semilla de maíz para forraje', 172.14, 94, '2026-05-16', 7, 1, '2025-08-02'),
(7, 'Cepillo Curador', 'Para limpieza de pezuñas', 58.76, 16, '2025-11-18', 5, 9, '2025-08-08'),
(8, 'Henolac', 'Suplemento lácteo para becerros', 40.39, 29, '2026-05-21', 3, 7, '2025-08-05'),
(9, 'Pienso Cerdo Feliz', 'Alimento balanceado para porcinos', 115.01, 40, '2025-07-10', 1, 1, '2025-08-04'),
(10, 'Malla Sombra', 'Protección solar para corrales', 83.16, 47, '2025-12-10', 4, 3, '2025-08-03'),
(11, 'tortillas de palomo', 'no se', 130.00, 40, '2025-08-09', 1, 8, '2025-08-04'),
(12, 'espolones', 'navajas para gallo', 179.99, 20, '2025-08-01', 4, 2, '2025-08-09'),
(13, 'Oroduras', 'Herraduras de oro p/ caballo', 200.00, 20, NULL, 4, 8, '2025-08-09'),
(14, 'Maiz azul', 'maiz para cerdos', 200.00, 20, NULL, 1, 1, '2025-08-09');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedores`
--

CREATE TABLE `proveedores` (
  `id_proveedor` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `contacto` varchar(100) DEFAULT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `direccion` varchar(150) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `proveedores`
--

INSERT INTO `proveedores` (`id_proveedor`, `nombre`, `contacto`, `telefono`, `direccion`) VALUES
(1, 'Granja Santa Anita', 'Juan Hernández', '5567890123', 'Camino Viejo a Tepotzotlán KM 12'),
(2, 'AgroVeterinaria El Charro', 'María Rodríguez', '5554321098', 'Calle Hidalgo #45, San Miguel'),
(3, 'Semillas del Valle', 'Carlos Mendoza', '5543216547', 'Boulevard Agrícola #120, Texcoco'),
(4, 'Distribuidora Rancho Grande', 'Roberto Jiménez', '5537894561', 'Carretera Libre a Querétaro KM 8'),
(5, 'Herrajes Campestres', 'Luisa Fernández', '5526549873', 'Avenida Juárez #78, Tultepec'),
(6, 'Forrajes La Pradera', 'Pedro Vargas', '5571234560', 'Camino a San Pablo #34, Xochimilco'),
(7, 'Veterinaria El Establo', 'Ana Morales', '5589632147', 'Callejón del Molino #5, Tlahuac'),
(8, 'Equipos Agrícolas Don Pancho', 'Francisco López', '5598765432', 'Vía Láctea S/N, Milpa Alta'),
(9, 'Suplementos Ganaderos', 'Miguel Ángel Cruz', '5512345678', 'Cerro del Tepeyac #67, Ecatepec'),
(10, 'Distribuidora La Vaquita Feliz', 'Guadalupe Reyes', '5501987654', 'Calzada San Juan #90, Chalco');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `servicios`
--

CREATE TABLE `servicios` (
  `id_servicio` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `servicios`
--

INSERT INTO `servicios` (`id_servicio`, `nombre`, `descripcion`, `precio`) VALUES
(1, 'Vacunación de Hat', 'Aplicación de vacunas a ganado', 102.74),
(2, 'Corte de Pezuñas', 'Mantenimiento preventivo para bovinos', 78.26),
(3, 'Inseminación Artificial', 'Servicio de reproducción asistida', 65.06),
(4, 'Desparasitación', 'Tratamiento antiparasitario general', 41.00),
(5, 'Atención de Parto', 'Asistencia en nacimientos', 122.97),
(6, 'Castración', 'Procedimiento quirúrgico', 198.61),
(7, 'Curación de Heridas', 'Tratamiento de lesiones en campo', 84.12),
(8, 'Ecografía Reproductiva', 'Monitoreo de gestación', 147.83),
(9, 'Visita de Emergencia', 'Servicio 24hrs para urgencias', 242.93),
(10, 'Recorte de Pico', 'Para aves de corral', 33.23);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` bigint(20) UNSIGNED NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `rol` varchar(20) NOT NULL DEFAULT 'asistente',
  `telefono` varchar(20) DEFAULT NULL,
  `activo` tinyint(1) DEFAULT 1,
  `fecha_registro` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `nombre`, `email`, `password`, `rol`, `telefono`, `activo`, `fecha_registro`) VALUES
(1, 'admin', 'admin@admin.com', 'password', 'admin', '4426558032', 1, '2025-08-09 18:02:22'),
(2, 'Omar Maldonado Bermudez', 'omarM@gmail.com', 'scrypt:32768:8:1$W54Dkx9DzrYgAaZx$76b364b6be1b51f93725d9fd73917b6682a5094cb15821de5757c6c2eeae657039c4963e9396f1a75a39e346b3831b7a4f93c3327529af0709dc842758a589cd', 'veterinario', '4423351233', 1, '2025-08-09 18:13:49');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ventas`
--

CREATE TABLE `ventas` (
  `id_venta` bigint(20) UNSIGNED NOT NULL,
  `cliente_id` int(11) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `total` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `ventas`
--

INSERT INTO `ventas` (`id_venta`, `cliente_id`, `fecha`, `total`) VALUES
(1, NULL, '2025-08-09', 803.28);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `animales`
--
ALTER TABLE `animales`
  ADD PRIMARY KEY (`id_animal`);

--
-- Indices de la tabla `aplicacionesservicio`
--
ALTER TABLE `aplicacionesservicio`
  ADD PRIMARY KEY (`id_aplicacion`);

--
-- Indices de la tabla `categorias_productos`
--
ALTER TABLE `categorias_productos`
  ADD PRIMARY KEY (`id_categoria`);

--
-- Indices de la tabla `citas`
--
ALTER TABLE `citas`
  ADD PRIMARY KEY (`id_cita`);

--
-- Indices de la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD PRIMARY KEY (`id_cliente`);

--
-- Indices de la tabla `configuraciones`
--
ALTER TABLE `configuraciones`
  ADD PRIMARY KEY (`id_config`),
  ADD UNIQUE KEY `clave` (`clave`);

--
-- Indices de la tabla `detallespedidos`
--
ALTER TABLE `detallespedidos`
  ADD PRIMARY KEY (`id_detalle_pedido`);

--
-- Indices de la tabla `detallesventas`
--
ALTER TABLE `detallesventas`
  ADD PRIMARY KEY (`id_detalle`);

--
-- Indices de la tabla `estatus`
--
ALTER TABLE `estatus`
  ADD PRIMARY KEY (`id_estado`);

--
-- Indices de la tabla `historialmedico`
--
ALTER TABLE `historialmedico`
  ADD PRIMARY KEY (`id_historial`);

--
-- Indices de la tabla `inventario`
--
ALTER TABLE `inventario`
  ADD PRIMARY KEY (`id_movimiento`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`id_pedido`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`);

--
-- Indices de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  ADD PRIMARY KEY (`id_proveedor`);

--
-- Indices de la tabla `servicios`
--
ALTER TABLE `servicios`
  ADD PRIMARY KEY (`id_servicio`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indices de la tabla `ventas`
--
ALTER TABLE `ventas`
  ADD PRIMARY KEY (`id_venta`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `animales`
--
ALTER TABLE `animales`
  MODIFY `id_animal` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `aplicacionesservicio`
--
ALTER TABLE `aplicacionesservicio`
  MODIFY `id_aplicacion` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `categorias_productos`
--
ALTER TABLE `categorias_productos`
  MODIFY `id_categoria` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `citas`
--
ALTER TABLE `citas`
  MODIFY `id_cita` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `clientes`
--
ALTER TABLE `clientes`
  MODIFY `id_cliente` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT de la tabla `configuraciones`
--
ALTER TABLE `configuraciones`
  MODIFY `id_config` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `detallespedidos`
--
ALTER TABLE `detallespedidos`
  MODIFY `id_detalle_pedido` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `detallesventas`
--
ALTER TABLE `detallesventas`
  MODIFY `id_detalle` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `estatus`
--
ALTER TABLE `estatus`
  MODIFY `id_estado` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `historialmedico`
--
ALTER TABLE `historialmedico`
  MODIFY `id_historial` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `inventario`
--
ALTER TABLE `inventario`
  MODIFY `id_movimiento` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `id_pedido` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  MODIFY `id_proveedor` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `servicios`
--
ALTER TABLE `servicios`
  MODIFY `id_servicio` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `ventas`
--
ALTER TABLE `ventas`
  MODIFY `id_venta` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
