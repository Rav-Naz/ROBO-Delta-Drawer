import '../classes/drawn_line.dart';
import 'package:flutter/material.dart';

class Sketcher extends CustomPainter {
  final List<dynamic> lines;
  final _selectedColor = const Color.fromARGB(255, 30, 111, 233);
  final _selectedWidth = 2.0;

  Sketcher({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.redAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < lines.length; ++i) {
      if (lines[i] == null) continue;
      for (int j = 0; j < lines[i].path.length - 1; ++j) {
        if (lines[i].path[j] != null && lines[i].path[j + 1] != null) {
          paint.color = _selectedColor;
          paint.strokeWidth = _selectedWidth;
          canvas.drawLine(lines[i].path[j], lines[i].path[j + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(Sketcher oldDelegate) {
    return true;
  }
}
