import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Conexión con tu base de datos de Supabase
  await Supabase.initialize(
    url: 'https://fxlhqevpjdxdssohheyv.supabase.co',
    anonKey: 'sb_publishable_627cznn8jvY8dCd0X1q_pA_nOoRbbq_',
  );

  runApp(const MaterialApp(
    title: 'Almacén Escuelas',
    home: PedidosEscuelaScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

// Modelo de Producto
class Producto {
  final dynamic id;
  final String nombre;
  final String categoria;
  final String unidad;
  final double precio;
  int cantidad;

  Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.unidad,
    required this.precio,
    this.cantidad = 0,
  });
}

// Modelo para ítem fuera de catálogo
class ItemEspecial {
  final String descripcion;
  final int cantidad;
  final double precioEstimado;

  ItemEspecial({
    required this.descripcion,
    required this.cantidad,
    required this.precioEstimado,
  });

  double get subtotal => cantidad * precioEstimado;
}

class PedidosEscuelaScreen extends StatefulWidget {
  const PedidosEscuelaScreen({super.key});

  @override
  State<PedidosEscuelaScreen> createState() => _PedidosEscuelaScreenState();
}

class _PedidosEscuelaScreenState extends State<PedidosEscuelaScreen> {
  final supabase = Supabase.instance.client;

  // Escuela activa por defecto (Escuela Río Colorado - ID 1)
  int escuelaId = 1;
  String nombreEscuela = "Escuela Río Colorado (Patagora)";
  double presupuestoMensual = 1200000.0;

  List<Producto> catalogo = [];
  final List<ItemEspecial> itemsEspeciales = [];
  bool cargando = true;
  String categoriaSeleccionada = "Todos";
  String textoBusqueda = "";
  DateTime? fechaEntregaSugerida;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // Traer datos de Supabase en tiempo real
  Future<void> _cargarDatos() async {
    try {
      final resEscuela = await supabase.from('escuelas').select().eq('id', escuelaId).maybeSingle();
      if (resEscuela != null) {
        nombreEscuela = resEscuela['nombre'] ?? nombreEscuela;
        presupuestoMensual = (resEscuela['presupuesto_mensual'] as num?)?.toDouble() ?? presupuestoMensual;
      }

      final resProductos = await supabase.from('productos').select().eq('activo', true);
      final List<Producto> lista = [];
      for (var p in resProductos) {
        lista.add(Producto(
          id: p['id'],
          nombre: p['nombre'] ?? '',
          categoria: p['categoria'] ?? 'General',
          unidad: p['unidad_medida'] ?? 'Unidad',
          precio: (p['precio_unitario'] as num?)?.toDouble() ?? 0.0,
        ));
      }

      setState(() {
        catalogo = lista;
        cargando = false;
      });
    } catch (e) {
      setState(() => cargando = false);
    }
  }

  // Cálculos de montos
  double get totalCatalogo => catalogo.fold(0, (acc, item) => acc + (item.cantidad * item.precio));
  double get totalEspeciales => itemsEspeciales.fold(0, (acc, item) => acc + item.subtotal);
  double get totalGeneral => totalCatalogo + totalEspeciales;

  // Semáforo de presupuesto
  Color get colorSemaforo {
    final porcentaje = (totalGeneral / presupuestoMensual);
    if (porcentaje <= 0.85) return Colors.green.shade700;
    if (porcentaje <= 1.0) return Colors.amber.shade800;
    return Colors.red.shade700;
  }

  String get estadoSemaforoTexto {
    final porcentaje = (totalGeneral / presupuestoMensual);
    if (porcentaje <= 0.85) return "Dentro de presupuesto";
    if (porcentaje <= 1.0) return "Próximo al límite";
    return "Supera presupuesto (ajuste posterior)";
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final categorias = ["Todos", ...{for (var p in catalogo) p.categoria}];

    final productosFiltrados = catalogo.where((p) {
      final coincideCat = categoriaSeleccionada == "Todos" || p.categoria == categoriaSeleccionada;
      final coincideTexto = p.nombre.toLowerCase().contains(textoBusqueda.toLowerCase());
      return coincideCat && coincideTexto;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombreEscuela, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Presupuesto: ${f.format(presupuestoMensual)}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Semáforo presupuestario
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: colorSemaforo.withOpacity(0.12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total pedido: ${f.format(totalGeneral)}",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorSemaforo)),
                          Text(estadoSemaforoTexto, style: TextStyle(fontSize: 12, color: colorSemaforo)),
                        ],
                      ),
                      Icon(Icons.traffic, color: colorSemaforo, size: 28),
                    ],
                  ),
                ),

                // Buscador
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar producto...",
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => setState(() => textoBusqueda = v),
                  ),
                ),

                // Filtro por categorías
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: categorias.map((cat) {
                      final isSelected = categoriaSeleccionada == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => setState(() => categoriaSeleccionada = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Lista de productos
                Expanded(
                  child: ListView.builder(
                    itemCount: productosFiltrados.length,
                    itemBuilder: (context, index) {
                      final item = productosFiltrados[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: ListTile(
                          title: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text("${f.format(item.precio)} / ${item.unidad}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.cantidad > 0)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => setState(() => item.cantidad--),
                                ),
                              if (item.cantidad > 0)
                                Text("${item.cantidad}",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.teal),
                                onPressed: () => setState(() => item.cantidad++),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalItemEspecial,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text("Encargo Especial"),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: totalGeneral == 0 ? null : _abrirCierrePedido,
          child: Text("Revisar Pedido (${f.format(totalGeneral)})", style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  void _abrirModalItemEspecial() {
    final descCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: "1");
    final precioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Producto fuera de catálogo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Descripción del producto")),
            TextField(controller: cantCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cantidad")),
            TextField(controller: precioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Presupuesto estimativo (\$)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (descCtrl.text.isNotEmpty && precioCtrl.text.isNotEmpty) {
                setState(() {
                  itemsEspeciales.add(ItemEspecial(
                    descripcion: descCtrl.text,
                    cantidad: int.tryParse(cantCtrl.text) ?? 1,
                    precioEstimado: double.tryParse(precioCtrl.text) ?? 0.0,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Agregar al pedido"),
          ),
        ],
      ),
    );
  }

  void _abrirCierrePedido() {
    final fechaMinima = DateTime.now().add(const Duration(days: 4));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Confirmación de Pedido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                "La entrega requiere un margen mínimo de 4 días y queda sujeta a la logística de reparto.",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const Divider(height: 24),
              ListTile(
                title: Text(fechaEntregaSugerida == null
                    ? "Seleccionar fecha de entrega sugerida"
                    : "Fecha elegida: ${DateFormat('dd/MM/yyyy').format(fechaEntregaSugerida!)}"),
                trailing: const Icon(Icons.calendar_month, color: Colors.teal),
                onTap: () async {
                  final sel = await showDatePicker(
                    context: context,
                    initialDate: fechaMinima,
                    firstDate: fechaMinima,
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (sel != null) {
                    setState(() => fechaEntregaSugerida = sel);
                    setModalState(() {});
                  }
                },
              ),
              if (itemsEspeciales.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text("Ítems especiales agregados:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...itemsEspeciales.map((e) => Text("• ${e.cantidad}x ${e.descripcion} (Est: \$${e.subtotal})")),
              ],
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: fechaEntregaSugerida == null ? null : () => _enviarPedido(ctx),
                child: const Text("Confirmar y Enviar Pedido al Almacén"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviarPedido(BuildContext dialogContext) async {
    try {
      final resPedido = await supabase.from('pedidos').insert({
        'escuela_id': escuelaId,
        'fecha_solicitada_entrega': DateFormat('yyyy-MM-dd').format(fechaEntregaSugerida!),
        'estado': 'cotizacion',
        'total_estimado': totalGeneral,
        'observaciones': 'Pedido cargado desde app Android',
      }).select().single();

      final pedidoId = resPedido['id'];

      List<Map<String, dynamic>> itemsParaInsertar = [];
      for (var p in catalogo.where((i) => i.cantidad > 0)) {
        itemsParaInsertar.add({
          'pedido_id': pedidoId,
          'producto_id': p.id,
          'descripcion_item': p.nombre,
          'cantidad': p.cantidad,
          'precio_unitario': p.precio,
          'subtotal': p.cantidad * p.precio,
          'es_especial': false,
        });
      }
      for (var e in itemsEspeciales) {
        itemsParaInsertar.add({
          'pedido_id': pedidoId,
          'producto_id': null,
          'descripcion_item': e.descripcion,
          'cantidad': e.cantidad,
          'precio_unitario': e.precioEstimado,
          'subtotal': e.subtotal,
          'es_especial': true,
        });
      }

      if (itemsParaInsertar.isNotEmpty) {
        await supabase.from('pedido_items').insert(itemsParaInsertar);
      }

      if (mounted) {
        Navigator.pop(dialogContext);
        setState(() {
          for (var p in catalogo) {
            p.cantidad = 0;
          }
          itemsEspeciales.clear();
          fechaEntregaSugerida = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("¡Pedido enviado con éxito al almacén!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al enviar pedido: $e"), backgroundColor: Colors.red),
      );
    }
  }
}
