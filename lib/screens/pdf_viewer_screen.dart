import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.path,
    this.title = "Document",
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int? pages = 0;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.shareXFiles([XFile(widget.path)], text: widget.title);
            },
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: 0,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onRender: (_pages) {
              setState(() {
                pages = _pages;
                isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                errorMessage = error.toString();
              });
              debugPrint("PDF Error: $error");
            },
            onPageError: (page, error) {
              setState(() {
                errorMessage = '$page: $error';
              });
              debugPrint("PDF Page Error: $page - $error");
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // controller = pdfViewController;
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                currentPage = page;
              });
            },
          ),
          if (!isReady) const Center(child: CircularProgressIndicator()),
          if (errorMessage.isNotEmpty) Center(child: Text(errorMessage)),
        ],
      ),
      floatingActionButton: isReady
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${currentPage! + 1} / $pages",
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
