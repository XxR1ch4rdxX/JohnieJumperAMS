from flask import Flask, render_template, request, redirect, url_for
from flask_mysqldb import MySQL

app = Flask(__name__)

app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = 'R1ch4rd0Suk1li'
app.config['MYSQL_DB'] = 'johniejummperams'

mysql = MySQL(app)

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

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
    nombre = request.form['nombre']
    descripcion = request.form['descripcion']
    precio = float(request.form['precio'])
    stock = int(request.form['stock'])
    fecha_caducidad = request.form['fecha_caducidad'] or None
    categoria_id = int(request.form['categoria'])
    proveedor_id = int(request.form['proveedor'])
    
    cur = mysql.connection.cursor()
    cur.execute("""
        INSERT INTO productos (nombre, descripcion, precio, stock, fecha_caducidad, categoria_id, proveedor_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (nombre, descripcion, precio, stock, fecha_caducidad, categoria_id, proveedor_id))
    
    mysql.connection.commit()
    cur.close()
    
    return redirect(url_for('productos'))

if __name__ == '__main__':
    app.run(debug=True)