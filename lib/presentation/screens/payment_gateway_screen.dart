import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/cart_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/catalogo_provider.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/database_provider.dart';
import 'package:gestor_invetarios_pedidos_app/core/services/notification_service.dart';
import 'package:gestor_invetarios_pedidos_app/data/models/cart_item.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentGatewayScreen extends ConsumerStatefulWidget {
  const PaymentGatewayScreen({super.key});

  @override
  ConsumerState<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends ConsumerState<PaymentGatewayScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _isProcessing = false;
  bool _paymentSuccess = false;
  String _generatedReceiptId = '';

  List<CartItem> _purchasedItems = [];
  double _purchasedTotal = 0.0;

  // Animación para el giro de la tarjeta (CVV focus)
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: pi).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));

    _cvvController.addListener(() {
      if (_cvvController.text.isNotEmpty && !_showBack) {
        setState(() {
          _showBack = true;
          _flipController.forward();
        });
      } else if (_cvvController.text.isEmpty && _showBack) {
        setState(() {
          _showBack = false;
          _flipController.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    if (value.isEmpty) return 'XXXX XXXX XXXX XXXX';
    final padded = value.padRight(16, 'X');
    return '${padded.substring(0, 4)} ${padded.substring(4, 8)} ${padded.substring(8, 12)} ${padded.substring(12, 16)}';
  }

  String _getCardType(String number) {
    if (number.startsWith('4')) return 'VISA';
    if (number.startsWith('5')) return 'MASTERCARD';
    if (number.startsWith('3')) return 'AMEX';
    return 'CREDIT CARD';
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    // Simular retraso de pasarela de pago (autenticación 3D Secure, validación bancaria)
    await Future.delayed(const Duration(milliseconds: 2500));

    // Registrar pedido en Firestore
    final user = ref.read(authStateProvider);
    final cartItems = ref.read(cartProvider);
    final totalToPay = ref.read(cartTotalProvider);
    final cartCount = ref.read(cartCountProvider);

    _purchasedItems = List.from(cartItems);
    _purchasedTotal = totalToPay;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se encontró sesión de usuario.')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      final orderData = {
        'fecha_pedido': DateTime.now().toIso8601String(),
        'distribuidor_id': null,
        'inversionista_id': null,
        'inversionista_nombre': 'COMPRA DIRECTA',
        'comprador_id': user.id,
        'comprador_nombre': user.nombre,
        'cantidad': cartCount,
        'capital_invertido': totalToPay,
        'ganancia_esperada': totalToPay * 0.10, // Simulación de ganancia operativa
        'capital_devuelto': 0.0,
        'devolucion_capital': 0.0,
        'ganancia_real': 0.0,
        'items': cartItems.map((item) => {
          'producto_id': item.producto.id,
          'cantidad': item.cantidad,
          'nombre': item.producto.nombre,
          'precio_unitario': item.producto.precioUnitario,
        }).toList(),
        'producto_nombre': cartItems.length == 1 
            ? cartItems.first.producto.nombre 
            : '${cartItems.first.producto.nombre} y ${cartItems.length - 1} más',
        'notas': 'Compra procesada mediante pasarela de pagos digital.',
        'estado': 'pendiente'
      };

      final result = await firestoreService.createPedido(orderData);
      _generatedReceiptId = result['id'] ?? 'REC-${Random().nextInt(900000) + 100000}';

      // Limpiar el carrito y actualizar proveedores
      ref.read(cartProvider.notifier).clear();
      ref.refresh(ordersFutureProvider);

      setState(() {
        _isProcessing = false;
        _paymentSuccess = true;
      });

      // Feedback Háptico Premium
      HapticFeedback.heavyImpact();

      // Disparar Notificación Local de Pedido Exitoso
      try {
        await NotificationService().showNotification(
          id: Random().nextInt(100000),
          title: '🛍️ ¡Pedido Completado Exitosamente!',
          body: 'El recibo $_generatedReceiptId por S/ ${totalToPay.toStringAsFixed(2)} ha sido registrado y está pendiente de despacho.',
        );
      } catch (err) {
        debugPrint('Error al mostrar notificación local: $err');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar pedido: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _generatePdfInvoice() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'COMERCIALIZADORA ALY',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange,
                          ),
                        ),
                        pw.Text('Herramientas y Materiales de Construccion'),
                        pw.Text('RUC: 20123456789'),
                        pw.Text('Direccion: Calle Real 456, Huancayo'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'BOLETA ELECTRONICA',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              pw.Text(
                                _generatedReceiptId,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.orange,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                // Client Info
                pw.Text(
                  'DATOS DEL CLIENTE',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.orange,
                  ),
                ),
                pw.Divider(color: PdfColors.orange, thickness: 1),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Nombre: ${ref.read(authStateProvider)?.nombre ?? "Cliente General"}'),
                    pw.Text('Fecha: ${DateTime.now().toString().split(' ')[0]}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Usuario: ${ref.read(authStateProvider)?.usuario ?? ""}'),
                    pw.Text('Metodo Pago: Tarjeta de Credito/Debito'),
                  ],
                ),
                pw.SizedBox(height: 30),
                // Items Table
                pw.Text(
                  'DETALLE DE COMPRA',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.orange,
                  ),
                ),
                pw.Divider(color: PdfColors.orange, thickness: 1),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Cant.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('P. Unitario', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Subtotal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    ..._purchasedItems.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item.producto.nombre, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('${item.cantidad} ${item.producto.unidad}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('S/ ${item.producto.precioUnitario.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('S/ ${item.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('Subtotal: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text('S/ ${(_purchasedTotal / 1.18).toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text('I.G.V. (18%): ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text('S/ ${(_purchasedTotal - (_purchasedTotal / 1.18)).toStringAsFixed(2)}'),
                          ],
                        ),
                        pw.Divider(color: PdfColors.grey),
                        pw.Row(
                          children: [
                            pw.Text('Total a Pagar: ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                            pw.Text('S/ ${_purchasedTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Gracias por comprar en Comercializadora Aly!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
                      pw.SizedBox(height: 4),
                      pw.Text('Representacion impresa de la Boleta Electronica.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Boleta_Aly_$_generatedReceiptId.pdf',
      );
    } catch (e) {
      debugPrint('Error al imprimir/guardar PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalToPay = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: _paymentSuccess 
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          _paymentSuccess ? 'RECEPCIÓN DE COMPRA' : 'PASARELA DE PAGOS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
      ),
      body: _paymentSuccess
          ? _buildSuccessReceipt(context, totalToPay)
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        // Tarjeta interactiva animada
                        Center(child: _buildAnimatedCard()),
                        const SizedBox(height: 32),
                        // Campos de Formulario
                        Text(
                          'INFORMACIÓN DE FACTURACIÓN',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCardHolderField(),
                        const SizedBox(height: 16),
                        _buildCardNumberField(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildExpiryField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildCVVField()),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _buildPayButton(totalToPay),
                        const SizedBox(height: 20),
                        _buildSecureShield(),
                      ],
                    ),
                  ),
                ),
                if (_isProcessing) _buildProcessingOverlay(),
              ],
            ),
    );
  }

  Widget _buildAnimatedCard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value;
        final isBack = angle >= pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspectiva 3D
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isBack 
              ? Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _buildCardBack(),
                )
              : _buildCardFront(),
        );
      },
    );
  }

  Widget _buildCardFront() {
    final rawNumber = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
    final cardNumberStr = _formatCardNumber(rawNumber);
    final cardHolderStr = _cardHolderController.text.isEmpty 
        ? 'NOMBRE DEL TITULAR' 
        : _cardHolderController.text.toUpperCase();
    final expiryStr = _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;
    final cardType = _getCardType(rawNumber);

    return Container(
      width: 320,
      height: 190,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF020617),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chip de tarjeta
              Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Text(
                cardType,
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            cardNumberStr,
            style: GoogleFonts.shareTechMono(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARD HOLDER',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cardHolderStr,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EXPIRES',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expiryStr,
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    final cvvStr = _cvvController.text.isEmpty ? 'XXX' : _cvvController.text;

    return Container(
      width: 320,
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF020617),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Banda magnética
          Container(
            height: 40,
            color: Colors.black,
          ),
          const SizedBox(height: 24),
          // Firma y CVV
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 35,
                    color: Colors.white.withOpacity(0.2),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _cardHolderController.text.toUpperCase(),
                      style: GoogleFonts.caveat(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 60,
                  height: 35,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Text(
                    cvvStr,
                    style: GoogleFonts.shareTechMono(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'AUTHORIZED SIGNATURE. NOT VALID UNLESS SIGNED.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 6,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHolderField() {
    return TextFormField(
      controller: _cardHolderController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Nombre del Titular',
        hintText: 'COMO FIGURA EN LA TARJETA',
        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingrese el nombre del titular';
        }
        return null;
      },
      onChanged: (val) => setState(() {}),
    );
  }

  Widget _buildCardNumberField() {
    return TextFormField(
      controller: _cardNumberController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(16),
      ],
      decoration: const InputDecoration(
        labelText: 'Número de Tarjeta',
        hintText: '0000 0000 0000 0000',
        prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ingrese el número de tarjeta';
        }
        if (value.length < 16) {
          return 'El número debe tener 16 dígitos';
        }
        return null;
      },
      onChanged: (val) => setState(() {}),
    );
  }

  Widget _buildExpiryField() {
    return TextFormField(
      controller: _expiryController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
        _ExpiryInputFormatter(),
      ],
      decoration: const InputDecoration(
        labelText: 'Expiración',
        hintText: 'MM/YY',
        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Requerido';
        }
        if (value.length < 5) {
          return 'Inválido';
        }
        final parts = value.split('/');
        final month = int.tryParse(parts[0]) ?? 0;
        if (month < 1 || month > 12) {
          return 'Mes Inválido';
        }
        return null;
      },
      onChanged: (val) => setState(() {}),
    );
  }

  Widget _buildCVVField() {
    return TextFormField(
      controller: _cvvController,
      focusNode: FocusNode(),
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: const InputDecoration(
        labelText: 'CVV',
        hintText: '000',
        prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Requerido';
        }
        if (value.length < 3) {
          return 'Inválido';
        }
        return null;
      },
    );
  }

  Widget _buildPayButton(double total) {
    return ElevatedButton(
      onPressed: _processPayment,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentOrange,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security_rounded, size: 20),
          const SizedBox(width: 8),
          Text(
            'PAGAR AHORA · S/ ${total.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecureShield() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, color: AppTheme.textGray, size: 16),
        SizedBox(width: 8),
        Text(
          'Encriptación SSL de 256 bits. Conexión segura.',
          style: TextStyle(color: AppTheme.textGray, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
            ),
            const SizedBox(height: 24),
            Text(
              'PROCESANDO PAGO...',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Por favor no cierres la app ni presiones volver.',
              style: TextStyle(color: AppTheme.textGray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessReceipt(BuildContext context, double total) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.successGreen.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de Éxito
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.successGreen,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¡PAGO COMPLETADO!',
                style: GoogleFonts.outfit(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu pedido ha sido registrado con éxito.',
                style: TextStyle(color: AppTheme.textGray, fontSize: 12),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white10),
              ),
              // Datos del Recibo
              _buildReceiptRow('ID TRANSACCIÓN', _generatedReceiptId),
              const SizedBox(height: 8),
              _buildReceiptRow('FECHA / HORA', DateTime.now().toString().split('.')[0]),
              const SizedBox(height: 8),
              _buildReceiptRow('MÉTODO DE PAGO', 'TARJETA DE CRÉDITO'),
              const SizedBox(height: 8),
              _buildReceiptRow('ESTADO DEL PEDIDO', 'PENDIENTE DE DESPACHO', valueColor: AppTheme.accentOrange),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MONTO TOTAL',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'S/ ${total.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _generatePdfInvoice,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('IMPRIMIR / DESCARGAR BOLETA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // Volver al inicio o catálogo
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'FINALIZAR Y CERRAR',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textGray,
            fontWeight: FontWeight.bold,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Formateador de texto personalizado para Expiración (MM/YY)
class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }
    
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
