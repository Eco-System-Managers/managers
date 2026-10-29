import 'dart:typed_data';

import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/contrato.dart';

// as cores do documento: os neutros do tema claro do Design System, porque
// o PDF é sempre impresso sobre branco. o azul fica de fora: num contrato
// não há ação
final _ink = PdfColor.fromInt(BrandColors.light.ink.toARGB32());
final _inkMuted = PdfColor.fromInt(BrandColors.light.inkMuted.toARGB32());
final _borda = PdfColor.fromInt(BrandColors.light.border.toARGB32());

// as medidas são de impressão (pontos), não da interface: o documento segue
// o padrão de papel, não a escala do app
const _margem = pw.EdgeInsets.symmetric(horizontal: 56, vertical: 64);
const _fonteDoTitulo = 18.0;
const _fonteDoTexto = 11.0;
const _fonteDoDetalhe = 10.0;
const _fonteDoRodape = 9.0;
const _entrelinha = 3.0;
const _vaoCurto = 4.0;
const _vaoDoParagrafo = 6.0;
const _vaoDaDivisoria = 24.0;
const _vaoEntreAssinaturas = 32.0;
const _vaoAteAssinaturas = 48.0;
const _espessuraDaLinha = 0.8;

// o PDF que o negócio manda para o cliente: o texto congelado do contrato,
// com cabeçalho e as linhas de assinatura. é só montagem; nada vai à API
Future<Uint8List> gerarPdfDoContrato(
  Contrato contrato, {
  required String negocioNome,
}) {
  final documento = pw.Document(
    title: contrato.titulo,
    author: negocioNome,
    theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(color: _ink)),
  );

  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: _margem,
      footer: (contexto) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${contexto.pageNumber} / ${contexto.pagesCount}',
          style: pw.TextStyle(fontSize: _fonteDoRodape, color: _inkMuted),
        ),
      ),
      build: (_) => [
        if (negocioNome.isNotEmpty)
          pw.Text(
            negocioNome,
            style: pw.TextStyle(fontSize: _fonteDoTexto, color: _inkMuted),
          ),
        pw.SizedBox(height: _vaoDoParagrafo),
        pw.Text(
          contrato.titulo,
          style: pw.TextStyle(
            fontSize: _fonteDoTitulo,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: _vaoCurto),
        pw.Text(
          'Cliente: ${contrato.clienteNome} · '
          'Gerado em ${formatarData(contrato.criadoEm)}',
          style: pw.TextStyle(fontSize: _fonteDoDetalhe, color: _inkMuted),
        ),
        pw.Divider(height: _vaoDaDivisoria, color: _borda),
        // o corpo vem com as quebras de linha do modelo: cada bloco é um
        // parágrafo, para o texto quebrar entre páginas sem cortar linha
        for (final paragrafo in contrato.corpo.split('\n'))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: _vaoDoParagrafo),
            child: pw.Text(
              paragrafo,
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(
                fontSize: _fonteDoTexto,
                lineSpacing: _entrelinha,
              ),
            ),
          ),
        pw.SizedBox(height: _vaoAteAssinaturas),
        pw.Row(
          children: [
            pw.Expanded(child: _linhaDeAssinatura(contrato.clienteNome)),
            pw.SizedBox(width: _vaoEntreAssinaturas),
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
      pw.Divider(color: _ink, thickness: _espessuraDaLinha),
      pw.Text(nome, style: const pw.TextStyle(fontSize: _fonteDoDetalhe)),
    ],
  );
}
