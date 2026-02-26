import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has network connectivity.
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  late final StreamSubscription<List<ConnectivityResult>> _sub;

  ConnectivityNotifier() : super(true) {
    // Check current state immediately
    Connectivity().checkConnectivity().then(_update);
    // Listen for changes
    _sub = Connectivity().onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    state = results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
