import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class MisFacturasScreen extends StatefulWidget {
  const MisFacturasScreen({super.key});

  @override
  State<MisFacturasScreen> createState() => _MisFacturasScreenState();
}

class _MisFacturasScreenState extends State<MisFacturasScreen> {
  List<FileSystemEntity> _pdfFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdfs();
  }

  Future<void> _loadPdfs() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      final pdfs = files.where((file) {
        return file.path.endsWith('.pdf') && file.path.contains('Boleta_Aly_');
      }).toList();

      // Ordenar por fecha de modificación (los más recientes primero)
      pdfs.sort((a, b) {
        final statA = File(a.path).statSync();
        final statB = File(b.path).statSync();
        return statB.modified.compareTo(statA.modified);
      });

      setState(() {
        _pdfFiles = pdfs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar PDFs: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: file.path.split(Platform.pathSeparator).last,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir el archivo: $e')),
        );
      }
    }
  }
  
  Future<void> _deletePdf(File file) async {
    try {
      await file.delete();
      _loadPdfs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recibo eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'MIS FACTURAS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange))
          : _pdfFiles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.accentOrange,
                  backgroundColor: AppTheme.surfaceDark,
                  onRefresh: _loadPdfs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pdfFiles.length,
                    itemBuilder: (context, index) {
                      final file = File(_pdfFiles[index].path);
                      final fileName = file.path.split(Platform.pathSeparator).last;
                      final stat = file.statSync();
                      
                      return _buildPdfCard(file, fileName, stat);
                    },
                  ),
                ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.textGray.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'No hay facturas',
            style: TextStyle(color: AppTheme.textGray, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las compras que realices aparecerán aquí',
            style: TextStyle(color: AppTheme.textGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(File file, String fileName, FileStat stat) {
    final sizeKb = (stat.size / 1024).toStringAsFixed(1);
    final dateStr = '${stat.modified.day.toString().padLeft(2, '0')}/${stat.modified.month.toString().padLeft(2, '0')}/${stat.modified.year}';
    final timeStr = '${stat.modified.hour.toString().padLeft(2, '0')}:${stat.modified.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.accentOrange),
        ),
        title: Text(
          fileName.replaceAll('.pdf', ''),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$dateStr $timeStr • $sizeKb KB',
            style: const TextStyle(color: AppTheme.textGray, fontSize: 11),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 20),
              onPressed: () => _openPdf(file),
              tooltip: 'Ver / Imprimir',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _showDeleteConfirm(file),
              tooltip: 'Eliminar',
            ),
          ],
        ),
        onTap: () => _openPdf(file),
      ),
    );
  }
  
  void _showDeleteConfirm(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Eliminar Recibo', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de eliminar este recibo de tu dispositivo?',
          style: TextStyle(color: AppTheme.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePdf(file);
            },
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
