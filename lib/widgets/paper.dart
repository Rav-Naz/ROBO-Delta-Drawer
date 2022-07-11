import 'dart:collection';
import 'dart:convert';

import 'package:provider/provider.dart';

import '../classes/drawn_line.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../functions/sketcher.dart';
import '../providers/request_queue_provider.dart';


class PaperWidget extends StatefulWidget {

  Function clear = () => {};
  final requestQueue = Queue();

  PaperWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PaperWidgetState();
}

class _PaperWidgetState extends State<PaperWidget> {

  final int _sheetWidth = 297;
  final int _sheetHeight = 210;
  final GlobalKey _sheetKey = GlobalKey();
  Size _sheetSize = const Size(0.0, 0.0);
  late RequestQueueProvider _requestQueueProvider;

  final _selectedColor = const Color.fromARGB(255, 30, 111, 233);
  final _selectedWidth = 2.0;
  DrawnLine line = DrawnLine([], Colors.black, 2.0);

  @override
  void initState() {
    widget.clear = clear;
    super.initState();
  }

  void clear() {
    setState(() {
      line = DrawnLine([const Offset(0.0, 0.0)], _selectedColor, _selectedWidth);
    });
  }

  void _onPanStart(DragStartDetails details) {
    _requestQueueProvider.startPainting();
    final point = details.localPosition;
    setState(() {
      _sheetSize = _sheetKey.currentContext!.size!;
      line = DrawnLine([point], _selectedColor, _selectedWidth);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final point = details.localPosition;
    if (point.dx > 0 &&
        point.dx < _sheetSize.width &&
        point.dy > 0 &&
        point.dy < _sheetSize.height) {
      final path = List<Offset>.from(line.path)..add(point);
      setState(() {
        line = DrawnLine(path, _selectedColor, _selectedWidth);
      });
      _requestQueueProvider.addRequestToQueue(createAlbum(point));
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _requestQueueProvider.stopPainting();
  }

  Future<http.Response> createAlbum(Offset position) {
    return http.post(
      Uri.parse('http://127.0.0.1:5000/companies'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, double>{
        'x': position.dx,
        'y': position.dy
      }),
    );
}

  @override
  Widget build(BuildContext context) {
    _requestQueueProvider = Provider.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(30.0),
        child: Align(
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: _sheetWidth / _sheetHeight,
            child: Container(
                key: _sheetKey,
                color: Color.fromARGB(255, 253, 242, 203),
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: Sketcher(lines: [line]),
                    ),
                  ),
                )),
          ),
        ),
      ),
    );
  }
}
