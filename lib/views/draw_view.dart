import 'package:delta_drawer/providers/request_queue_provider.dart';
import 'package:delta_drawer/widgets/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../widgets/circular_progress.dart';


class DrawView extends StatefulWidget {
  const DrawView({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _DrawViewState();
}

class _DrawViewState extends State<DrawView> {
  final double _sidePercentWidth = 0.1;
  PaperWidget paperWidget = PaperWidget();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            Container(
              width: MediaQuery.of(context).size.width * _sidePercentWidth,
              constraints: const BoxConstraints(minWidth: 75.0),
              decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/png/border.png"),
                    fit: BoxFit.cover,
                    alignment: Alignment.topRight),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    LayoutBuilder(builder:
                        (BuildContext context, BoxConstraints constraints) {
                      return Container(
                        height: double.infinity,
                        constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.3,
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.6),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SvgPicture.asset("assets/svg/ROBO_Delta.svg"),
                        ),
                      );
                    }),
                    IconButton(
                      onPressed: () => {paperWidget.clear()},
                      icon: const Icon(Icons.delete),
                      color: Colors.white,
                      iconSize: 50.0,
                    )
                  ],
                ),
              ),
            ),
            paperWidget
          ],
        ),
        AnimatedOpacity(
          opacity: Provider.of<RequestQueueProvider>(context)
                .isRequestsProcessingAndNotPainting ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Visibility(
            visible: Provider.of<RequestQueueProvider>(context)
                .isRequestsProcessingAndNotPainting,
            child: Container(
                color: Provider.of<RequestQueueProvider>(context)
                .isConnectionError ? Color.fromARGB(153, 240, 6, 6) : Color.fromARGB(153, 31, 25, 25),
                child: Center(
                  child: Provider.of<RequestQueueProvider>(context)
                .isConnectionError ?
                Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: EdgeInsets.all(30.0),
                        child: const SizedBox(
                          width: 200.0,
                          height: 200.0,
                          child: Icon(Icons.error_outline, size: 200.0, color: Colors.white)
                        ),
                      ),
                      Text("Utracono połączenie. Sprawdź komunikację z serwerem a nastepnie zrestartuj aplikacje.", style: TextStyle(fontSize: 20.0, color: Colors.white),)
                    ],
                  )
                :
                Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: EdgeInsets.all(30.0),
                        child: SizedBox(
                          width: 200.0,
                          height: 200.0,
                          child: Stack(
                            children: [ CircleProgressBar(
                              foregroundColor: Color.fromARGB(255, 247, 204, 13),
                              backgroundColor: Colors.transparent,
                              value: Provider.of<RequestQueueProvider>(context).processedPercentage,
                            ),
                            Center(child: Text("${(Provider.of<RequestQueueProvider>(context).processedPercentage*100 as double).toInt()}%", style: TextStyle(fontSize: 50.0, color: Color.fromARGB(255, 247, 204, 13)),))
                            ],
                          ),
                        ),
                      ),
                      Text("Trwa rysowanie obrazka. Proszę czekać.", style: TextStyle(fontSize: 20.0, color: Color.fromARGB(255, 247, 204, 13)),)
                    ],
                  ),
                ),
            )
          ),
        )
      ],
    );
  }
}
