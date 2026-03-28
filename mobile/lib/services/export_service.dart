import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Genera y comparte un reporte de historial individual en PDF
  static Future<void> exportarHistorialIndividualPdf(Map<String, dynamic> animalData, List salud, List monitoreo, List eventos) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          // LOGO / ENCABEZADO AGRO CONTROL PRO
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#01579B'), // azulAgro
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('AGRO CONTROL PRO', style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('Reporte Oficial', style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Header(
            level: 1,
            text: 'Historial de Animal: ${animalData['arete_siniiga'] ?? "Sin Arete"}',
          ),
          pw.Paragraph(text: 'Arete Interno: ${animalData['arete_interno'] ?? "N/A"}'),
          pw.Paragraph(text: 'UPP Inicial: ${animalData['upp'] ?? "N/A"}'),
          pw.Divider(),

          pw.Header(level: 2, text: 'Reportes de Salud Recientes'),
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Síntomas', 'Tratamiento'],
            data: salud.map((r) => [
              _formatDate(r['fecha_registro']),
              r['descripcion_sintomas'] ?? 'N/A',
              r['tratamiento'] ?? 'N/A'
            ]).toList(),
          ),

          pw.SizedBox(height: 20),

          pw.Header(level: 2, text: 'Eventos Críticos Registrados'),
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Tipo de Evento', 'Descripción'],
            data: eventos.map((e) => [
              _formatDate(e['fecha_registro']),
              e['tipo_evento'] ?? 'N/A',
              e['descripcion'] ?? 'N/A'
            ]).toList(),
          ),

          pw.SizedBox(height: 20),

          pw.Header(level: 1, text: 'Última Telemetría Automática'),
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Temp °C', 'Actividad'],
            data: monitoreo.map((m) => [
              _formatDate(m['timestamp']),
              m['temperatura']?.toString() ?? 'N/A',
              m['actividad'] ?? 'N/A'
            ]).toList(),
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Reporte_Animal_${animalData['arete_siniiga']}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Historial Animal');
  }

  /// Genera y comparte un reporte de historial individual en Excel
  static Future<void> exportarHistorialIndividualExcel(Map<String, dynamic> animalData, List salud, List monitoreo, List eventos) async {
    var excel = Excel.createExcel();
    
    // Hoja 1: Salud
    Sheet sheetSalud = excel['Salud'];
    sheetSalud.appendRow([TextCellValue('AGRO CONTROL PRO - REPORTE DE HISTORIAL ANIMAL')]);
    sheetSalud.appendRow([TextCellValue('Fecha'), TextCellValue('Síntomas'), TextCellValue('Tratamiento')]);
    for (var r in salud) {
      sheetSalud.appendRow([
        TextCellValue(_formatDate(r['fecha_registro'])),
        TextCellValue(r['descripcion_sintomas'] ?? 'N/A'),
        TextCellValue(r['tratamiento'] ?? 'N/A')
      ]);
    }

    // Hoja 2: Monitoreo
    Sheet sheetMonit = excel['Monitoreo'];
    sheetMonit.appendRow([TextCellValue('Fecha'), TextCellValue('Temp °C'), TextCellValue('Actividad')]);
    for (var m in monitoreo) {
      sheetMonit.appendRow([
        TextCellValue(_formatDate(m['timestamp'])),
        TextCellValue(m['temperatura']?.toString() ?? 'N/A'),
        TextCellValue(m['actividad'] ?? 'N/A')
      ]);
    }

    // Hoja 3: Eventos Críticos
    Sheet sheetEventos = excel['Eventos Críticos'];
    sheetEventos.appendRow([TextCellValue('Fecha'), TextCellValue('Tipo de Evento'), TextCellValue('Descripción')]);
    for (var e in eventos) {
      sheetEventos.appendRow([
        TextCellValue(_formatDate(e['fecha_registro'])),
        TextCellValue(e['tipo_evento'] ?? 'N/A'),
        TextCellValue(e['descripcion'] ?? 'N/A')
      ]);
    }

    // Eliminar la hoja por defecto (Sheet1) si no es la única
    excel.delete('Sheet1');

    final output = await getTemporaryDirectory();
    final fileName = '${output.path}/Reporte_Animal_${animalData['arete_siniiga']}.xlsx';
    final file = File(fileName);
    final bytes = excel.save();
    if(bytes != null){
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Historial Animal');
    }
  }

  /// Genera y comparte un reporte de Lotes en PDF
  static Future<void> exportarReporteLotesPdf(Map<String, dynamic> resumen, List compras, List ventas) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          // LOGO / ENCABEZADO AGRO CONTROL PRO
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#01579B'), // azulAgro
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('AGRO CONTROL PRO', style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('Reporte de Lotes', style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.Header(
            level: 1,
            text: 'Reporte Financiero y Movimientos de Lotes',
          ),
          pw.Paragraph(text: 'Resumen Global:'),
          pw.Bullet(text: 'Cabezas Compradas: ${resumen['compras']['cabezas']}'),
          pw.Bullet(text: 'Total Invertido: \$${resumen['compras']['monto']}'),
          pw.Bullet(text: 'Cabezas Vendidas: ${resumen['ventas']['cabezas']}'),
          pw.Bullet(text: 'Total Ingresado: \$${resumen['ventas']['monto']}'),
          pw.Bullet(text: 'Balance Neto: \$${resumen['balance']}'),
          
          pw.Divider(),
          
          pw.Header(level: 1, text: 'Historial de Compras de Lotes'),
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Proveedor', 'Cantidad', 'Costo Total'],
            data: compras.map((c) => [
              _formatDate(c['fecha_registro_sistema'] ?? c['fecha']),
              c['proveedor'] ?? 'N/A',
              c['cantidad_cabezas']?.toString() ?? 'N/A',
              '\$${c['total_pagado'] ?? 0}'
            ]).toList(),
          ),

          pw.SizedBox(height: 20),

          pw.Header(level: 1, text: 'Historial de Ventas (Salidas)'),
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Cliente', 'Cantidad', 'Ingreso Total'],
            data: ventas.map((v) => [
              _formatDate(v['fecha_registro_sistema'] ?? v['fecha_salida']),
              v['cliente'] ?? 'N/A',
              v['cantidad_cabezas']?.toString() ?? 'N/A',
              '\$${v['monto_total'] ?? 0}'
            ]).toList(),
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Reporte_Lotes.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Lotes de Ganado');
  }

  /// Genera y comparte un reporte de Lotes en Excel
  static Future<void> exportarReporteLotesExcel(Map<String, dynamic> resumen, List compras, List ventas) async {
    var excel = Excel.createExcel();
    
    // Resumen
    Sheet sheetResumen = excel['Resumen'];
    sheetResumen.appendRow([TextCellValue('AGRO CONTROL PRO - REPORTE DE LOTES (COMPRAS Y VENTAS)')]);
    sheetResumen.appendRow([TextCellValue('Concepto'), TextCellValue('Valor')]);
    sheetResumen.appendRow([TextCellValue('Total Cabezas Compradas'), TextCellValue(resumen['compras']['cabezas'].toString())]);
    sheetResumen.appendRow([TextCellValue('Monto Invertido'), TextCellValue(resumen['compras']['monto'].toString())]);
    sheetResumen.appendRow([TextCellValue('Total Cabezas Vendidas'), TextCellValue(resumen['ventas']['cabezas'].toString())]);
    sheetResumen.appendRow([TextCellValue('Monto Ganado'), TextCellValue(resumen['ventas']['monto'].toString())]);
    sheetResumen.appendRow([TextCellValue('Balance'), TextCellValue(resumen['balance'].toString())]);

    // Compras
    Sheet sheetCompras = excel['Compras'];
    sheetCompras.appendRow([TextCellValue('Fecha'), TextCellValue('Proveedor'), TextCellValue('Origen'), TextCellValue('Cabezas'), TextCellValue('Total')]);
    for (var c in compras) {
      sheetCompras.appendRow([
        TextCellValue(_formatDate(c['fecha_registro_sistema'] ?? c['fecha'])),
        TextCellValue(c['proveedor'] ?? 'N/A'),
        TextCellValue(c['origen'] ?? 'N/A'),
        TextCellValue(c['cantidad_cabezas']?.toString() ?? '0'),
        TextCellValue(c['total_pagado']?.toString() ?? '0'),
      ]);
    }

    // Ventas
    Sheet sheetVentas = excel['Ventas'];
    sheetVentas.appendRow([TextCellValue('Fecha'), TextCellValue('Cliente'), TextCellValue('Destino'), TextCellValue('Cabezas'), TextCellValue('Total')]);
    for (var v in ventas) {
      sheetVentas.appendRow([
        TextCellValue(_formatDate(v['fecha_registro_sistema'] ?? v['fecha_salida'])),
        TextCellValue(v['cliente'] ?? 'N/A'),
        TextCellValue(v['destino'] ?? 'N/A'),
        TextCellValue(v['cantidad_cabezas']?.toString() ?? '0'),
        TextCellValue(v['monto_total']?.toString() ?? '0'),
      ]);
    }

    // Eliminar la hoja por defecto
    excel.delete('Sheet1');

    final output = await getTemporaryDirectory();
    final fileName = '${output.path}/Reporte_Lotes.xlsx';
    final file = File(fileName);
    final bytes = excel.save();
    if(bytes != null){
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Lotes de Ganado');
    }
  }

  static String _formatDate(dynamic dateField) {
    if (dateField == null) return "N/A";
    
    // Si viene de Timestamp de Firestore (ej. {_seconds: 12345, _nanoseconds: 0}) map it
    if (dateField is Map && dateField['_seconds'] != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch((dateField['_seconds'] as int) * 1000);
      return "${dt.day}/${dt.month}/${dt.year}";
    }
    
    // Si es un string ISO
    if (dateField is String) {
      try {
        final dt = DateTime.parse(dateField);
        return "${dt.day}/${dt.month}/${dt.year}";
      } catch (_) {
        return dateField; 
      }
    }
    
    return dateField.toString();
  }
}
