import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Watches the OS-level network connectivity and exposes a simple stream
/// the rest of the app can subscribe to (e.g. to auto-pause/resume the
/// tunnel, or to warn the user when they lose internet mid-connect).
class NetworkManager {
  NetworkManager._internal();
  static final NetworkManager instance = NetworkManager._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Broadcasts `true` when the device has *some* network interface up,
  /// `false` when it doesn't. This is a coarse check (interface-level),
  /// not a guarantee of actual internet reachability.
  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  Future<void> start() async {
    // Prime the initial state.
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(initial);
    } catch (_) {
      _isOnline = true;
    }

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _resultsToOnline(results);
      if (online != _isOnline) {
        _isOnline = online;
        _onlineController.add(_isOnline);
      }
    });
  }

  bool _resultsToOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(results);
      return _isOnline;
    } catch (_) {
      return _isOnline;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
