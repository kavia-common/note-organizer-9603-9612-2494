import 'dart:async';

class ConnectivityMonitor {
  ConnectivityMonitor() {
    // For this scaffold (and to keep dependencies minimal), treat connectivity
    // as always-online. The sync engine still handles failures and backoff.
    //
    // If you later add `connectivity_plus`, replace this with real signals.
    _controller.add(true);
  }

  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get isOnlineStream => _controller.stream;

  bool get isOnline => true;

  void dispose() {
    _controller.close();
  }
}
