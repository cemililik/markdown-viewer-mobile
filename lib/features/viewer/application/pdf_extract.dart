// Application-layer re-export of PDF metadata extraction utilities.
//
// [extractPdfTitle], [extractMermaidCodes], and [exportToPdf] are
// implemented in the data layer alongside the PDF generation pipeline
// so they share the same markdown-parsing and entity-decoding path.
// This file re-exports them at the application boundary so
// [ViewerScreen] (presentation) is not directly coupled to the data
// layer, satisfying the layer dependency matrix.
export 'package:markdown_viewer/features/viewer/data/services/pdf_exporter.dart'
    show exportToPdf, extractMermaidCodes, extractPdfTitle;
