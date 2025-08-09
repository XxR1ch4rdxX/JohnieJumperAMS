-- Tabla de Clientes
CREATE TABLE Clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    telefono VARCHAR(20),
    direccion VARCHAR(150)
);

-- Tabla de Animales
CREATE TABLE Animales (
    id_animal SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    especie VARCHAR(50),
    raza VARCHAR(50),
    edad INT,
    cliente_id INT REFERENCES Clientes(id_cliente)
);

-- Tabla de Categorías de Productos
CREATE TABLE Categorias_Productos (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(50)
);

-- Tabla de Proveedores
CREATE TABLE Proveedores (
    id_proveedor SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    contacto VARCHAR(100),
    telefono VARCHAR(20),
    direccion VARCHAR(150)
);

-- Tabla de Productos
CREATE TABLE Productos (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    descripcion TEXT,
    precio DECIMAL(10, 2),
    stock INT,
    fecha_caducidad DATE,
    categoria_id INT REFERENCES Categorias_Productos(id_categoria),
    proveedor_id INT REFERENCES Proveedores(id_proveedor)
);

-- Tabla de Ventas
CREATE TABLE Ventas (
    id_venta SERIAL PRIMARY KEY,
    cliente_id INT REFERENCES Clientes(id_cliente),
    fecha DATE,
    total DECIMAL(10, 2)
);

-- Tabla de Detalles de Venta
CREATE TABLE DetallesVentas (
    id_detalle SERIAL PRIMARY KEY,
    venta_id INT REFERENCES Ventas(id_venta),
    producto_id INT REFERENCES Productos(id_producto),
    cantidad INT,
    precio_unitario DECIMAL(10, 2)
);

-- Tabla de Servicios
CREATE TABLE Servicios (
    id_servicio SERIAL PRIMARY KEY,
    nombre VARCHAR(100),
    descripcion TEXT,
    precio DECIMAL(10, 2)
);

-- Tabla de Aplicaciones de Servicios
CREATE TABLE AplicacionesServicio (
    id_aplicacion SERIAL PRIMARY KEY,
    animal_id INT REFERENCES Animales(id_animal),
    servicio_id INT REFERENCES Servicios(id_servicio),
    fecha DATE,
    observaciones TEXT
);

-- Tabla de Estatus (para Citas o Pedidos)
CREATE TABLE Estatus (
    id_estado SERIAL PRIMARY KEY,
    nombre VARCHAR(50)
);

-- Tabla de Citas
CREATE TABLE Citas (
    id_cita SERIAL PRIMARY KEY,
    cliente_id INT REFERENCES Clientes(id_cliente),
    animal_id INT REFERENCES Animales(id_animal),
    servicio_id INT REFERENCES Servicios(id_servicio),
    fecha DATE,
    estado_id INT REFERENCES Estatus(id_estado)
);

-- Tabla de Pedidos
CREATE TABLE Pedidos (
    id_pedido SERIAL PRIMARY KEY,
    proveedor_id INT REFERENCES Proveedores(id_proveedor),
    fecha DATE,
    estado_id INT REFERENCES Estatus(id_estado),
    total DECIMAL(10, 2)
);

-- Tabla de Detalles de Pedidos
CREATE TABLE DetallesPedidos (
    id_detalle_pedido SERIAL PRIMARY KEY,
    pedido_id INT REFERENCES Pedidos(id_pedido),
    producto_id INT REFERENCES Productos(id_producto),
    cantidad INT,
    precio_unitario DECIMAL(10, 2)
);
