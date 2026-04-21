import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

enum AutoRefreshReason {
  timer,
  connectivityRestored,
  appResumed,
  pullToRefresh,
}

mixin AutoRefreshStateMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoRefreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  AppLifecycleListener? _lifecycleListener;
  bool _hadConnection = true;
  bool _isConfigured = false;

  @protected
  Duration? get autoRefreshInterval;

  @protected
  bool get refreshOnConnectivityRestore => true;

  @protected
  bool get refreshOnAppResume => true;

  @protected
  bool get autoRefreshEnabled => true;

  @protected
  Future<void> onAutoRefresh(AutoRefreshReason reason, {required bool force});

  @protected
  void configureAutoRefresh() {
    if (_isConfigured) {
      return;
    }
    _isConfigured = true;

    final interval = autoRefreshInterval;
    if (autoRefreshEnabled && interval != null) {
      _autoRefreshTimer = Timer.periodic(interval, (_) {
        if (!mounted) {
          return;
        }
        unawaited(onAutoRefresh(AutoRefreshReason.timer, force: false));
      });
    }

    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!refreshOnAppResume || !mounted || !autoRefreshEnabled) {
          return;
        }
        unawaited(onAutoRefresh(AutoRefreshReason.appResumed, force: false));
      },
    );

    unawaited(_watchConnectivity());
  }

  @protected
  Future<void> triggerPullToRefresh() {
    return onAutoRefresh(AutoRefreshReason.pullToRefresh, force: true);
  }

  Future<void> _watchConnectivity() async {
    if (!refreshOnConnectivityRestore) {
      return;
    }

    try {
      _hadConnection = _hasConnection(await _connectivity.checkConnectivity());
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        results,
      ) {
        final hasConnection = _hasConnection(results);
        final recovered = !_hadConnection && hasConnection;
        _hadConnection = hasConnection;

        if (!recovered || !mounted || !autoRefreshEnabled) {
          return;
        }
        unawaited(
          onAutoRefresh(AutoRefreshReason.connectivityRestored, force: false),
        );
      });
    } catch (_) {}
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((item) => item != ConnectivityResult.none);
  }

  void dispose() {
    _autoRefreshTimer?.cancel();
    _lifecycleListener?.dispose();
    unawaited(_connectivitySubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
