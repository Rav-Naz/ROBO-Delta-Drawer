import 'package:flutter/cupertino.dart';
import 'package:queue/queue.dart';

class RequestQueueProvider extends ChangeNotifier {
  final queue = Queue();
  late final remainingItemsStream;
  bool isPainting = false;
  bool isConnectionError = false;
  int remainingRequest = 0;
  int _requestCount = 0;
  int _requestCompleted = 0;

  RequestQueueProvider() {
    remainingItemsStream = queue.remainingItems.listen((numberOfItems) {
      remainingRequest = numberOfItems;
      notifyListeners();
    });
  }

  void resetCount() {
    _requestCount = 0;
    _requestCompleted = 0;
  }

  void startPainting() {
    isPainting = true;
    notifyListeners();
  }

  void stopPainting() {
    isPainting = false;
    notifyListeners();
  }

  get processedPercentage {
    if (_requestCompleted != 0 && _requestCount != 0) {
      return (_requestCompleted / _requestCount).toDouble();
    } else {
      return 0.0;
    }
  }

  get isRequestsProcessingAndNotPainting {
    return processedPercentage != 0 && !isPainting;
  }

  void addRequestToQueue(Future request) {
    _requestCount++;
      queue.add(() => request).catchError((_,__) {
        isConnectionError = true;
        notifyListeners();
      }).then((_) {
        _requestCompleted++;
        if (_requestCompleted == _requestCount &&
            isRequestsProcessingAndNotPainting) {
          Future.delayed(const Duration(seconds: 1)).then((_) {
            if (!isConnectionError) {
              resetCount();
              notifyListeners();
            }
          });
        }
      });
      notifyListeners();
  }
}
