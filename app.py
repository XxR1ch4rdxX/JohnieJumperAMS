# Reemplaza tu app.py existente con este código corregido
from flask_moment import Moment
from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from flask_mysqldb import MySQL
from werkzeug.security import generate_password_hash, check_password_hash
import datetime

app = Flask(__name__)
moment = Moment(app) 
app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = ''
app.config['MYSQL_DB'] = 'johniejummperams'
app.secret_key = 'tu_clave_secreta_aqui'
mysql = MySQL(app)

@app.route('/')
def dashboard():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    cur = mysql.connection.cursor()
    
    # Obtener estadísticas para el dashboard
    # Citas de hoy
    hoy = datetime.date.today().isoformat()
    cur.execute("""
        SELECT c.id_cita, cl.nombre as cliente, a.nombre as animal, 
               s.nombre as servicio, c.fecha, e.nombre as estado
        FROM citas c
        LEFT JOIN clientes cl ON c.cliente_id = cl.id_cliente
        LEFT JOIN animales a ON c.animal_id = a.id_animal
        LEFT JOIN servicios s ON c.servicio_id = s.id_servicio
        LEFT JOIN estatus e ON c.estado_id = e.id_estado
        WHERE c.fecha >= %s AND c.fecha < DATE_ADD(%s, INTERVAL 1 DAY)
        ORDER BY c.fecha
    """, [hoy, hoy])
    citas_hoy = cur.fetchall()

    # Ventas del mes
    cur.execute("""
        SELECT IFNULL(SUM(total), 0) as ventas_mes
        FROM ventas 
        WHERE YEAR(fecha) = YEAR(CURDATE()) 
        AND MONTH(fecha) = MONTH(CURDATE())
    """)
    ventas_mes = cur.fetchone()[0]

    # Productos con stock bajo
    cur.execute("SELECT * FROM productos WHERE stock < 10")
    productos_stock_bajo = cur.fetchall()

    cur.close()
    
    return render_template('dashboard.html', 
                         citas_hoy=citas_hoy,
                         ventas_mes=ventas_mes,
                         productos_stock_bajo=productos_stock_bajo)

@app.route('/productos')
def productos():
    filtro = request.args.get('filtro')
    valor = request.args.get('valor')
    nombre = request.args.get('nombre', '')

    cur = mysql.connection.cursor()

    # Obtener proveedores y categorías
    cur.execute("SELECT id_proveedor, nombre FROM proveedores ORDER BY nombre")
    proveedores = cur.fetchall()

    cur.execute("SELECT id_categoria, nombre FROM categorias_productos ORDER BY nombre")
    categorias = cur.fetchall()

    # Aplicar filtros
    if filtro == 'stock' and valor:
        cur.execute("CALL filtrar_stock_bajo(%s)", [int(valor)])
    elif filtro == 'caros' and valor:
        cur.execute("CALL filtrar_mas_caros(%s)", [int(valor)])
    elif filtro == 'proveedor' and valor:
        cur.execute("CALL filtrar_por_proveedor(%s)", [int(valor)])
    elif filtro == 'categoria' and valor:
        cur.execute("CALL filtrar_por_categoria(%s)", [int(valor)])
    elif filtro == 'fecha_proxima':
        cur.execute("CALL ordenar_por_fecha_caducidad_proxima()")
    elif nombre:
        cur.execute("CALL filtrar_productos_por_nombre(%s)", [f"%{nombre}%"])
    elif filtro == 'fecha_agregado':
        cur.execute("CALL filtrar_por_fecha_agregado()")
    else:
        cur.execute("CALL obtener_productos_detalle()")

    productos = cur.fetchall()
    cur.close()

    return render_template('productos.html',
                           productos=productos,
                           proveedores=proveedores,
                           categorias=categorias)

@app.route('/agregar_producto', methods=['POST'])
def agregar_producto():
    nombre = request.form.get('nombre', '').strip()
    descripcion = request.form.get('descripcion', '').strip() or None

    # validaciones simples
    try:
        precio = float(request.form.get('precio', 0))
    except ValueError:
        flash('Precio inválido', 'danger')
        return redirect(url_for('productos'))

    try:
        stock = int(request.form.get('stock', 0))
    except ValueError:
        flash('Stock inválido', 'danger')
        return redirect(url_for('productos'))

    # fecha de caducidad: vacía o checkbox "no_caduca" -> NULL
    if request.form.get('no_caduca'):
        fecha_caducidad = None
    else:
        fecha_raw = request.form.get('fecha_caducidad')
        fecha_caducidad = fecha_raw if fecha_raw else None

    # ids (asume select obliga a elegir)
    try:
        categoria_id = int(request.form.get('categoria'))
        proveedor_id = int(request.form.get('proveedor'))
    except (TypeError, ValueError):
        flash('Categoría o proveedor inválido', 'danger')
        return redirect(url_for('productos'))

    cur = mysql.connection.cursor()
    cur.execute("""
        INSERT INTO productos (nombre, descripcion, precio, stock, fecha_caducidad, categoria_id, proveedor_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (nombre, descripcion, precio, stock, fecha_caducidad, categoria_id, proveedor_id))

    mysql.connection.commit()
    cur.close()

    flash('Producto agregado', 'success')
    return redirect(url_for('productos'))

@app.route('/eliminar_producto', methods=['POST'])
def eliminar_producto():
    try:
        producto_id = request.form['id']

        cur = mysql.connection.cursor()

        # Verificar si el producto existe
        cur.execute("SELECT id_producto FROM productos WHERE id_producto = %s", [producto_id])
        if not cur.fetchone():
            return jsonify({'success': False, 'error': 'El producto no existe'})

        # Usar el procedimiento almacenado para eliminar
        cur.callproc('eliminar_producto', [producto_id])
        mysql.connection.commit()
        cur.close()

        return jsonify({'success': True})

    except Exception as e:
        mysql.connection.rollback()
        return jsonify({'success': False, 'error': str(e)})

# Funciones de autenticación
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']

        cur = mysql.connection.cursor()
        cur.execute("SELECT * FROM usuarios WHERE email = %s", [email])
        user = cur.fetchone()
        cur.close()

        if user and user[3] == password:
            session['user_id'] = user[0]
            session['user_name'] = user[1]
            session['user_role'] = user[4]
            flash('Inicio de sesión exitoso', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('Credenciales incorrectas', 'danger')

    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    flash('Has cerrado sesión', 'info')
    return redirect(url_for('login'))

# Middleware para verificar autenticación
@app.before_request
def require_login():
    allowed_routes = ['login', 'static']
    if request.endpoint not in allowed_routes and 'user_id' not in session:
        return redirect(url_for('login'))

# Rutas para citas
@app.route('/citas')
def citas():
    cur = mysql.connection.cursor()

    # Obtener citas para hoy
    hoy = datetime.date.today().isoformat()
    cur.execute("""
        SELECT c.id_cita, cl.nombre as cliente, a.nombre as animal, 
               s.nombre as servicio, c.fecha, e.nombre as estado
        FROM citas c
        LEFT JOIN clientes cl ON c.cliente_id = cl.id_cliente
        LEFT JOIN animales a ON c.animal_id = a.id_animal
        LEFT JOIN servicios s ON c.servicio_id = s.id_servicio
        LEFT JOIN estatus e ON c.estado_id = e.id_estado
        WHERE c.fecha >= %s AND c.fecha < DATE_ADD(%s, INTERVAL 1 DAY)
        ORDER BY c.fecha
    """, [hoy, hoy])
    citas_hoy = cur.fetchall()

    # Obtener todas las citas próximas
    cur.execute("""
        SELECT c.id_cita, cl.nombre as cliente, a.nombre as animal, 
               s.nombre as servicio, c.fecha, e.nombre as estado
        FROM citas c
        LEFT JOIN clientes cl ON c.cliente_id = cl.id_cliente
        LEFT JOIN animales a ON c.animal_id = a.id_animal
        LEFT JOIN servicios s ON c.servicio_id = s.id_servicio
        LEFT JOIN estatus e ON c.estado_id = e.id_estado
        WHERE c.fecha >= %s
        ORDER BY c.fecha
        LIMIT 50
    """, [hoy])
    citas_proximas = cur.fetchall()

    # Obtener clientes, animales y servicios para el formulario
    cur.execute("SELECT id_cliente, nombre FROM clientes ORDER BY nombre")
    clientes = cur.fetchall()

    cur.execute("SELECT id_animal, nombre FROM animales ORDER BY nombre")
    animales = cur.fetchall()

    cur.execute("SELECT id_servicio, nombre FROM servicios ORDER BY nombre")
    servicios = cur.fetchall()

    cur.execute("SELECT id_estado, nombre FROM estatus ORDER BY nombre")
    estados = cur.fetchall()

    cur.close()
    return render_template('citas.html',
                           citas_hoy=citas_hoy,
                           citas_proximas=citas_proximas,
                           clientes=clientes,
                           animales=animales,
                           servicios=servicios,
                           estados=estados,
                           datetime=datetime)

@app.route('/agendar_cita', methods=['POST'])
def agendar_cita():
    try:
        # Primero crear/verificar cliente
        cur = mysql.connection.cursor()

        # Insertar cliente si no existe
        cur.execute("""
            INSERT INTO clientes (nombre, telefono, direccion)
            VALUES (%s, %s, %s)
            ON DUPLICATE KEY UPDATE telefono=VALUES(telefono), direccion=VALUES(direccion)
        """, (
            request.form['nombre_cliente'],
            request.form.get('telefono_cliente'),
            request.form.get('direccion_cliente')
        ))

        # Obtener ID del cliente
        cliente_id = cur.lastrowid if cur.lastrowid else cur.execute(
            "SELECT id_cliente FROM clientes WHERE nombre = %s",
            [request.form['nombre_cliente']]
        ).fetchone()[0]

        # Insertar animal
        cur.execute("""
            INSERT INTO animales (nombre, especie, raza, edad, sexo, cliente_id)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            request.form['nombre_animal'],
            request.form['especie_animal'],
            request.form.get('raza_animal'),
            request.form.get('edad_animal'),
            request.form.get('sexo_animal'),
            cliente_id
        ))
        animal_id = cur.lastrowid

        # Insertar cita
        fecha_completa = f"{request.form['fecha_cita']} {request.form['hora_cita']}"
        cur.execute("""
            INSERT INTO citas (cliente_id, animal_id, servicio_id, fecha, estado_id, observaciones)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            cliente_id,
            animal_id,
            1,  # ID de servicio genérico
            fecha_completa,
            1,  # Estado "Pendiente"
            f"Motivo: {request.form['motivo_cita']}\nObservaciones: {request.form.get('observaciones_cita', '')}"
        ))

        mysql.connection.commit()
        cur.close()

        flash('Cita agendada correctamente', 'success')
    except Exception as e:
        mysql.connection.rollback()
        flash(f'Error al agendar cita: {str(e)}', 'danger')

    return redirect(url_for('citas'))

# Rutas para gestión de clientes y animales
@app.route('/clientes')
def clientes():
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM clientes ORDER BY nombre")
    clientes = cur.fetchall()
    cur.close()
    return render_template('clientes.html', clientes=clientes)

@app.route('/animales/<int:cliente_id>')
def animales_cliente(cliente_id):
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM animales WHERE cliente_id = %s", [cliente_id])
    animales = cur.fetchall()
    cur.close()
    return render_template('animales.html', animales=animales)

# Rutas para informes/dashboard
@app.route('/informes')
def informes():
    cur = mysql.connection.cursor()

    # Ventas del mes
    cur.execute("""
        SELECT DATE_FORMAT(fecha, '%Y-%m') as mes, SUM(total) as total
        FROM ventas
        WHERE fecha >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
        GROUP BY mes
        ORDER BY mes
    """)
    ventas_mensuales = cur.fetchall()

    # Productos más vendidos
    cur.execute("""
        SELECT p.nombre, SUM(dv.cantidad) as total_vendido
        FROM detallesventas dv
        JOIN productos p ON dv.producto_id = p.id_producto
        GROUP BY p.nombre
        ORDER BY total_vendido DESC
        LIMIT 5
    """)
    productos_top = cur.fetchall()

    # Servicios más solicitados
    cur.execute("""
        SELECT s.nombre, COUNT(*) as total
        FROM citas c
        JOIN servicios s ON c.servicio_id = s.id_servicio
        WHERE c.fecha >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
        GROUP BY s.nombre
        ORDER BY total DESC
        LIMIT 5
    """)
    servicios_top = cur.fetchall()

    cur.close()
    return render_template('informes.html',
                           ventas_mensuales=ventas_mensuales,
                           productos_top=productos_top,
                           servicios_top=servicios_top)

@app.route('/registro', methods=['GET', 'POST'])
def registro():
    if 'user_id' in session and session.get('user_role') != 'admin':
        flash('Solo los administradores pueden crear usuarios', 'danger')
        return redirect(url_for('dashboard'))

    if request.method == 'POST':
        nombre = request.form['nombre']
        email = request.form['email']
        password = request.form['password']
        rol = request.form.get('rol', 'asistente')
        telefono = request.form.get('telefono', '')

        # Validaciones básicas
        if not nombre or not email or not password:
            flash('Todos los campos son obligatorios', 'danger')
            return redirect(url_for('registro'))

        # Encriptar contraseña
        hashed_password = generate_password_hash(password)

        try:
            cur = mysql.connection.cursor()
            cur.execute("""
                INSERT INTO usuarios (nombre, email, password, rol, telefono)
                VALUES (%s, %s, %s, %s, %s)
            """, (nombre, email, hashed_password, rol, telefono))
            mysql.connection.commit()
            cur.close()

            flash('Usuario registrado exitosamente', 'success')
            return redirect(url_for('dashboard'))
        except Exception as e:
            mysql.connection.rollback()
            flash('Error al registrar usuario: ' + str(e), 'danger')

    # Si es GET o hay error en POST, mostrar formulario
    return render_template('registro.html')

@app.route('/usuarios')
def listar_usuarios():
    if 'user_id' not in session or session.get('user_role') != 'admin':
        flash('Acceso no autorizado', 'danger')
        return redirect(url_for('dashboard'))

    cur = mysql.connection.cursor()
    cur.execute("SELECT id_usuario, nombre, email, rol, telefono, activo FROM usuarios ORDER BY nombre")
    usuarios = cur.fetchall()
    cur.close()

    return render_template('usuarios.html', usuarios=usuarios)

# RUTAS DE VENTAS
@app.route('/ventas')
def ventas():
    cur = mysql.connection.cursor()
    
    # Obtener productos disponibles
    cur.execute("""
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
        ORDER BY p.nombre
    """)
    productos = cur.fetchall()
    
    cur.close()
    return render_template('ventas_mejorada.html', productos=productos)

@app.route('/procesar_venta', methods=['POST'])
def procesar_venta():
    try:
        # Obtener los productos vendidos del formulario
        productos = []
        for key, value in request.form.items():
            if key.startswith('producto_'):
                producto_id = key.replace('producto_', '')
                cantidad = int(value)
                if cantidad > 0:
                    productos.append({'id': producto_id, 'cantidad': cantidad})

        if not productos:
            flash('Debe seleccionar al menos un producto', 'danger')
            return redirect(url_for('ventas'))

        cur = mysql.connection.cursor()

        # Calcular total
        total = 0
        for producto in productos:
            cur.execute("SELECT precio, stock FROM productos WHERE id_producto = %s", [producto['id']])
            result = cur.fetchone()
            if not result:
                flash(f"Producto ID {producto['id']} no encontrado", 'danger')
                return redirect(url_for('ventas'))
            
            precio, stock = result
            if producto['cantidad'] > stock:
                flash(f"No hay suficiente stock para el producto ID {producto['id']}", 'danger')
                return redirect(url_for('ventas'))

            total += precio * producto['cantidad']

        # Registrar venta
        cur.execute("INSERT INTO ventas (fecha, total) VALUES (NOW(), %s)", [total])
        venta_id = cur.lastrowid

        # Registrar detalles de venta y actualizar stock
        for producto in productos:
            cur.execute("SELECT precio FROM productos WHERE id_producto = %s", [producto['id']])
            precio = cur.fetchone()[0]

            # Insertar detalle de venta
            cur.execute("""
                INSERT INTO detallesventas (venta_id, producto_id, cantidad, precio_unitario)
                VALUES (%s, %s, %s, %s)
            """, (venta_id, producto['id'], producto['cantidad'], precio))
            
            # Actualizar stock
            cur.execute("""
                UPDATE productos 
                SET stock = stock - %s 
                WHERE id_producto = %s
            """, (producto['cantidad'], producto['id']))

        mysql.connection.commit()
        cur.close()

        flash(f'Venta registrada correctamente. Total: ${total:.2f}', 'success')
        return redirect(url_for('ventas'))

    except Exception as e:
        mysql.connection.rollback()
        flash(f'Error al procesar la venta: {str(e)}', 'danger')
        return redirect(url_for('ventas'))

# RUTAS DE PEDIDOS
@app.route('/pedidos')
def pedidos():
    cur = mysql.connection.cursor()

    # Obtener productos con stock bajo
    cur.execute("""
        SELECT p.id_producto, p.nombre, p.stock, pr.nombre as proveedor,
               pr.id_proveedor, p.precio
        FROM productos p
        JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
        WHERE p.stock < 15
        ORDER BY p.stock ASC
    """)
    productos = cur.fetchall()

    # Obtener proveedores
    cur.execute("SELECT id_proveedor, nombre FROM proveedores ORDER BY nombre")
    proveedores = cur.fetchall()

    # Obtener pedidos pendientes
    cur.execute("""
        SELECT p.id_pedido, pr.nombre as proveedor, p.fecha, p.total,
               e.nombre as estado
        FROM pedidos p
        JOIN proveedores pr ON p.proveedor_id = pr.id_proveedor
        LEFT JOIN estatus e ON p.estado_id = e.id_estado
        WHERE p.estado_id IN (1, 2)
        ORDER BY p.fecha DESC
    """)
    pedidos_pendientes = cur.fetchall()

    cur.close()
    return render_template('pedidos_mejorado.html',
                           productos=productos,
                           proveedores=proveedores,
                           pedidos_pendientes=pedidos_pendientes)

@app.route('/procesar_pedido', methods=['POST'])
def procesar_pedido():
    try:
        proveedor_id = request.form['proveedor_id']
        productos = []

        # Recoger productos del formulario
        for key, value in request.form.items():
            if key.startswith('producto_'):
                producto_id = key.replace('producto_', '')
                cantidad = int(value)
                if cantidad > 0:
                    productos.append({
                        'id': producto_id,
                        'cantidad': cantidad
                    })

        if not productos:
            flash('Debe seleccionar al menos un producto', 'danger')
            return redirect(url_for('pedidos'))

        cur = mysql.connection.cursor()

        # Calcular total del pedido
        total = 0
        for producto in productos:
            cur.execute("SELECT precio FROM productos WHERE id_producto = %s", [producto['id']])
            precio = cur.fetchone()[0]
            total += precio * producto['cantidad']

        # Crear pedido
        cur.execute("""
            INSERT INTO pedidos (proveedor_id, fecha, estado_id, total)
            VALUES (%s, NOW(), %s, %s)
        """, (proveedor_id, 1, total))
        pedido_id = cur.lastrowid

        # Agregar detalles del pedido
        for producto in productos:
            cur.execute("SELECT precio FROM productos WHERE id_producto = %s", [producto['id']])
            precio = cur.fetchone()[0]

            cur.execute("""
                INSERT INTO detallespedidos (pedido_id, producto_id, cantidad, precio_unitario)
                VALUES (%s, %s, %s, %s)
            """, (pedido_id, producto['id'], producto['cantidad'], precio))

        mysql.connection.commit()
        cur.close()

        flash(f'Pedido #{pedido_id} registrado correctamente. Total: ${total:.2f}', 'success')
        return redirect(url_for('pedidos'))

    except Exception as e:
        mysql.connection.rollback()
        flash(f'Error al procesar el pedido: {str(e)}', 'danger')
        return redirect(url_for('pedidos'))

@app.route('/recibir_pedido/<int:pedido_id>')
def recibir_pedido(pedido_id):
    try:
        cur = mysql.connection.cursor()

        # Obtener detalles del pedido
        cur.execute("""
            SELECT producto_id, cantidad 
            FROM detallespedidos 
            WHERE pedido_id = %s
        """, [pedido_id])
        detalles = cur.fetchall()

        # Actualizar stock de cada producto
        for detalle in detalles:
            producto_id, cantidad = detalle
            cur.execute("""
                UPDATE productos 
                SET stock = stock + %s 
                WHERE id_producto = %s
            """, (cantidad, producto_id))

        # Marcar pedido como completado
        cur.execute("""
            UPDATE pedidos 
            SET estado_id = 3 
            WHERE id_pedido = %s
        """, [pedido_id])

        mysql.connection.commit()
        cur.close()

        flash('Pedido marcado como recibido y stock actualizado', 'success')
        return redirect(url_for('pedidos'))

    except Exception as e:
        mysql.connection.rollback()
        flash(f'Error al recibir pedido: {str(e)}', 'danger')
        return redirect(url_for('pedidos'))

if __name__ == '__main__':
    app.run(debug=True)