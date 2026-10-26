import 'dart:typed_data';

import 'package:managers/core/utils/datas.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/contrato.dart';

// o PDF que o negócio manda para o cliente: o texto congelado do contrato,
// com cabeçalho e as linhas de assinatura. é só montagem; nada vai à API
Future<Uint8List> gerarPdfDoContrato(
  Contrato contrato, {
  required String negocioNome,
}) {
  final documento = pw.Document(title: contrato.titulo, author: negocioNome);

  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 64),
      footer: (contexto) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${contexto.pageNumber} / ${contexto.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (_) => [
        if (negocioNome.isNotEmpty)
          pw.Text(
            negocioNome,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        pw.SizedBox(height: 6),
        pw.Text(
          contrato.titulo,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Cliente: ${contrato.clienteNome} · '
          'Gerado em ${formatarData(contrato.criadoEm)}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Divider(height: 24),
        // o corpo vem com as quebras de linha do modelo: cada bloco é um
        // parágrafo, para o texto quebrar entre páginas sem cortar linha
        for (final paragrafo in contrato.corpo.split('\n'))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              paragrafo,
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
            ),
          ),
        pw.SizedBox(height: 48),
        pw.Row(
          children: [
            pw.Expanded(child: _linhaDeAssinatura(contrato.clienteNome)),
            pw.SizedBox(width: 32),
            pw.Expanded(child: _linhaDeAssinatura(negocioNome)),
          ],
        ),
      ],
    ),
  );

  return documento.save();
}

pw.Widget _linhaDeAssinatura(String nome) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Divider(color: PdfColors.grey800, thickness: 0.8),
      pw.Text(nome, style: const pw.TextStyle(fontSize: 10)),
    ],
  );
}
