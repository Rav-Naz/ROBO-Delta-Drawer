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
  final Offset _minDeltaCoords = const Offset(0, 0);
  final Offset _maxDeltaCoords = const Offset(2, 2);
  double _zWhilePrinting = 180.0;
  double _zIdle = 170.0;
  final double _pauseBetweenSavingPointsInMiliseconds = 50;
  final int _delayBetweenSendingCoords = 200;
  final GlobalKey _sheetKey = GlobalKey();
  Size _sheetSize = const Size(0.0, 0.0);
  late RequestQueueProvider _requestQueueProvider;
  StreamController<List<DrawnLine>> linesStreamController =
      StreamController<List<DrawnLine>>.broadcast();
  StreamController<DrawnLine> currentLineStreamController =
      StreamController<DrawnLine>.broadcast();
  int lastSavedPointTimestamp = DateTime.now().millisecondsSinceEpoch;

  bool isDebug = true;

  DrawnLine line = DrawnLine([]);
  List<DrawnLine> lines = [];

  @override
  void initState() {
    _zIdle = _zWhilePrinting-10;
    widget.clear = _clear;
    linesStreamController.stream.listen((event) async {
      for (var i = 0; i < event.last.path.length; i++) {
        var item = event.last.path[i];
        if (i == event.last.path.length - 1) {
          await sendCords(item.dx, item.dy, _zWhilePrinting);
          _requestQueueProvider.addRequestToQueue(Future.delayed(
              Duration(milliseconds: _delayBetweenSendingCoords)));
          await sendCords(item.dx, item.dy, _zIdle);
          _requestQueueProvider.addRequestToQueue(Future.delayed(
              Duration(milliseconds: _delayBetweenSendingCoords)));
        } else {
          await sendCords(item.dx, item.dy, _zWhilePrinting);
          _requestQueueProvider.addRequestToQueue(Future.delayed(
              Duration(milliseconds: _delayBetweenSendingCoords)));
        }
      }
    });
    super.initState();
  }

  void _clear() async {
    await sendCords(_minDeltaCoords.dx, _minDeltaCoords.dy, _zIdle);
    setState(() {
      lines = [];
      line = DrawnLine([]);
      _requestQueueProvider.addRequestToQueue(
          Future.delayed(Duration(milliseconds: _delayBetweenSendingCoords)));
      Future.delayed(Duration(milliseconds: _delayBetweenSendingCoords * 2))
          .then((value) {
        _requestQueueProvider.resetCount();
      });
    });
  }

  void _onPanStart(DragStartDetails details) {
    _requestQueueProvider.startPainting();
    final point = details.localPosition;
    setState(() {
      lastSavedPointTimestamp = DateTime.now().millisecondsSinceEpoch;
      _sheetSize = _sheetKey.currentContext!.size!;
      line = DrawnLine([point]);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final point = details.localPosition;
    var circleCenter = Offset(sheetRadius, sheetRadius);
    var now = DateTime.now().millisecondsSinceEpoch;
    var z = 0.0;
    if (point.dx > 0 &&
        point.dx < _sheetSize.width &&
        point.dy > 0 &&
        point.dy < _sheetSize.height &&
        euklidianDistance(circleCenter, point) < sheetRadius &&
        (now - lastSavedPointTimestamp) >=
            _pauseBetweenSavingPointsInMiliseconds) {
      final path = List<Offset>.from(line.path)..add(point);
      setState(() {
        line = DrawnLine(path);
        lastSavedPointTimestamp = DateTime.now().millisecondsSinceEpoch;
      });
      currentLineStreamController.add(line);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    lines = List.from(lines)..add(line);
    linesStreamController.add(lines);
    lastSavedPointTimestamp = DateTime.now().millisecondsSinceEpoch;
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

  Future<http.Response> sendCords(double x, double y, double z) async {
    await Future.delayed(Duration(milliseconds: _delayBetweenSendingCoords));
    var deltaCoordsXY = screenCoordsToDeltaCords(Offset(x, y));
    var response = await http.post(
      Uri.parse(isDebug
          ? 'http://127.0.0.1:5000/companies'
          : 'http://raspberrypi:8000/deltabot/serialRelay'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode([
        ['C', deltaCoordsXY.dx, deltaCoordsXY.dy, z]
      ]),
    );
    return response;
  }

  @override
  Widget build(BuildContext context) {
    _requestQueueProvider = Provider.of(context);
    return Expanded(
      child: Container(
          margin: const EdgeInsets.all(30.0),
          child: Stack(children: [
            Positioned(
              right: MediaQuery.of(context).size.width * 0.01,
              top: MediaQuery.of(context).size.width * 0.01,
              child: AnimatedOpacity(
                opacity: Provider.of<RequestQueueProvider>(context)
                            .processedPercentage !=
                        0
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Visibility(
                  visible: Provider.of<RequestQueueProvider>(context)
                          .processedPercentage !=
                      0,
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
                            fontSize:
                                20 * 0.0005 * MediaQuery.of(context).size.width,
                            color: const Color.fromARGB(255, 247, 204, 13)),
                      )
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: MediaQuery.of(context).size.width * 0.03,
              bottom: MediaQuery.of(context).size.width * 0.01,
                child: RotatedBox(
              quarterTurns: 1,
              child: SizedBox(
                width: MediaQuery.of(context).size.height * 0.45,
                child: Slider(
                    min: 0.0,
                    max: 200.0,
                    value: _zWhilePrinting,
                    onChanged: (val) => {
                      setState(() {
                        _zWhilePrinting =val;
                        _zIdle = (_zWhilePrinting-10).clamp(0, 200);
                      })
                    },
                    activeColor: const Color.fromARGB(255, 247, 204, 13),
                    inactiveColor: const Color.fromARGB(143, 247, 204, 13)),
              ),
            )),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width*0.15),
              child: Align(
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
              ),
            )
          ])),
    );
  }
}
