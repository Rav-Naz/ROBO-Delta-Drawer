import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:provider/provider.dart';

import '../classes/drawn_line.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../functions/sketcher.dart';
import '../providers/request_queue_provider.dart';
import 'circular_progress.dart';

class PaperWidget extends StatefulWidget {
  Function clear = () => {};
  Function send = () => {};
  final requestQueue = Queue();

  PaperWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PaperWidgetState();
}

class _PaperWidgetState extends State<PaperWidget> {
  final _workspaceColor = Color.fromARGB(255, 250, 232, 167);
  final Offset _maxDeltaCoords = const Offset(2, 2);
  final Offset _minDeltaCoords = const Offset(-2, -2);
  final double _zWhilePrinting = 0.0;
  final double _zIdle = 10.0;
  final GlobalKey _sheetKey = GlobalKey();
  Size _sheetSize = const Size(0.0, 0.0);
  late RequestQueueProvider _requestQueueProvider;
  StreamController<List<DrawnLine>> linesStreamController =
      StreamController<List<DrawnLine>>.broadcast();
  StreamController<DrawnLine> currentLineStreamController =
      StreamController<DrawnLine>.broadcast();

  bool isDebug = true;

  DrawnLine line = DrawnLine([]);
  List<DrawnLine> lines = [];

  @override
  void initState() {
    widget.clear = _clear;
    linesStreamController.stream.listen((event) {
      for (var i = 0; i < event.last.path.length; i++) {
        var item = event.last.path[i];
        if (i == event.last.path.length - 1) {
          _requestQueueProvider
              .addRequestToQueue(sendCords(item.dx, item.dy, _zWhilePrinting));
          _requestQueueProvider
              .addRequestToQueue(sendCords(item.dx, item.dy, _zIdle));
        } else {
          _requestQueueProvider
              .addRequestToQueue(sendCords(item.dx, item.dy, _zWhilePrinting));
        }
      }
    });
    super.initState();
  }

  void _clear() {
    setState(() {
      lines = [];
      line = DrawnLine([]);
      _requestQueueProvider.addRequestToQueue(
          sendCords(_minDeltaCoords.dx, _minDeltaCoords.dy, _zIdle));
      Future.delayed(const Duration(milliseconds: 200)).then((value) {
        _requestQueueProvider.resetCount();
      });
    });
  }

  void _onPanStart(DragStartDetails details) {
    _requestQueueProvider.startPainting();
    final point = details.localPosition;
    setState(() {
      _sheetSize = _sheetKey.currentContext!.size!;
      line = DrawnLine([point]);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final point = details.localPosition;
    var circleCenter = Offset(sheetRadius, sheetRadius);
    var z = 0.0;
    if (point.dx > 0 &&
        point.dx < _sheetSize.width &&
        point.dy > 0 &&
        point.dy < _sheetSize.height &&
        euklidianDistance(circleCenter, point) < sheetRadius) {
      final path = List<Offset>.from(line.path)..add(point);
      setState(() {
        line = DrawnLine(path);
      });
      currentLineStreamController.add(line);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    lines = List.from(lines)..add(line);
    linesStreamController.add(lines);

    _requestQueueProvider.stopPainting();
  }

  double euklidianDistance(Offset pointA, Offset pointB) {
    return sqrt(pow(pointB.dx - pointA.dx, 2) + pow(pointB.dy - pointA.dy, 2));
  }

  double get sheetRadius {
    return _sheetSize.width / 2;
  }

  Offset screenCoordsToDeltaCords(Offset screenCoords) {
    Offset maxScreenCoords = Offset(_sheetSize.width, _sheetSize.height);
    Offset newCoords = Offset(
        normalization(screenCoords.dx, maxScreenCoords.dx, 0,
            _maxDeltaCoords.dx, _minDeltaCoords.dx),
        normalization(screenCoords.dy, maxScreenCoords.dy, 0,
            _maxDeltaCoords.dy, _minDeltaCoords.dy));
    return newCoords;
  }

  double normalization(double x, double currentMax, double currentMin,
      double newMax, double newMin) {
    return ((x - currentMin) / (currentMax - currentMin)) * (newMax - newMin) +
        newMin;
  }

  Future<http.Response> sendCords(double x, double y, double z) {
    return http.post(
      Uri.parse(isDebug
          ? 'http://127.0.0.1:5000/companies'
          : 'http://raspberrypi:8000/deltabot/serialRelay'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode([
        ['C', x, y, z]
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    _requestQueueProvider = Provider.of(context);
    return Expanded(
      child: Container(
          margin: const EdgeInsets.all(30.0),
          child: Stack(children: [
            Positioned(
              right: MediaQuery.of(context).size.width * 0.02,
              top: MediaQuery.of(context).size.width * 0.02,
              child: AnimatedOpacity(
                opacity: Provider.of<RequestQueueProvider>(context)
                                            .processedPercentage != 0
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Visibility(
                  visible: Provider.of<RequestQueueProvider>(context)
                                            .processedPercentage != 0,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(20.0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.05,
                            height: MediaQuery.of(context).size.width * 0.05,
                            child: Stack(
                              children: [
                                CircleProgressBar(
                                  foregroundColor:
                                      const Color.fromARGB(255, 247, 204, 13),
                                  backgroundColor: Colors.transparent,
                                  value:
                                      Provider.of<RequestQueueProvider>(context)
                                          .processedPercentage,
                                ),
                                Center(
                                    child: Text(
                                  "${(Provider.of<RequestQueueProvider>(context).processedPercentage * 100 as double).toInt()}%",
                                  style: TextStyle(
                                      fontSize: 30 *
                                          0.0005 *
                                          MediaQuery.of(context).size.width,
                                      color: const Color.fromARGB(
                                          255, 247, 204, 13)),
                                ))
                              ],
                            ),
                          ),
                        ),
                        Text(
                          "Postęp",
                          style: TextStyle(
                              fontSize: 20 *
                                  0.0005 *
                                  MediaQuery.of(context).size.width,
                              color: const Color.fromARGB(255, 247, 204, 13)),
                        )
                      ],
                    ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _workspaceColor,
                              Colors.white,
                              Colors.white,
                              _workspaceColor
                            ],
                            stops: const [
                              0.146,
                              0.146,
                              0.854,
                              0.854
                            ])),
                    clipBehavior: Clip.hardEdge,
                    key: _sheetKey,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: Container(
                            color: Colors.transparent,
                            alignment: Alignment.topLeft,
                            child: StreamBuilder<List<DrawnLine>>(
                              stream: linesStreamController.stream,
                              builder: (context, snapshot) {
                                return CustomPaint(
                                  painter: Sketcher(
                                    lines: lines,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: RepaintBoundary(
                            child: Container(
                              color: Colors.transparent,
                              alignment: Alignment.topLeft,
                              child: StreamBuilder<DrawnLine>(
                                stream: currentLineStreamController.stream,
                                builder: (context, snapshot) {
                                  return CustomPaint(
                                    painter: Sketcher(
                                      lines: [line],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      ],
                    )),
              ),
            )
          ])),
    );
  }
}
