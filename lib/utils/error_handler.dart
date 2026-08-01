import 'dart:io';
import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _tag = 'OryvexVPN';
  static bool _debugMode = kDebugMode;

  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  static void info(String message, [String? tag]) {
    if (_debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [${tag ?? _tag}] INFO: $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [${tag ?? _tag}] ERROR: $message');
    if (error != null) {
      print('  Error: $error');
    }
    if (stackTrace != null && _debugMode) {
      print('  StackTrace: $stackTrace');
    }
  }

  static void warning(String message, [String? tag]) {
    if (_debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [${tag ?? _tag}] WARNING: $message');
    }
  }

  static void debug(String message, [String? tag]) {
    if (_debugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [${tag ?? _tag}] DEBUG: $message');
    }
  }

  static void vpnEvent(String event, [Map<String, dynamic>? data]) {
    final timestamp = DateTime.now().toIso8601String();
    final dataStr = data != null ? ' | Data: $data' : '';
    print('[$timestamp] [VPN_EVENT] $event$dataStr');
  }

  static void connectionState(String state, [String? details]) {
    final timestamp = DateTime.now().toIso8601String();
    final detailsStr = details != null ? ' | $details' : '';
    print('[$timestamp] [CONNECTION] State: $state$detailsStr');
  }
}

class ErrorHandler {
  static String getUserFriendlyMessage(Object error) {
    final errorStr = error.toString();

    // Network errors
    if (errorStr.contains('SocketException') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('Failed host lookup')) {
      return 'خطا در اتصال به شبکه. لطفا اتصال اینترنت خود را بررسی کنید.';
    }

    // Timeout errors
    if (errorStr.contains('TimeoutException') || errorStr.contains('timeout')) {
      return 'زمان اتصال به پایان رسید. لطفا دوباره تلاش کنید.';
    }

    // WireGuard specific errors
    if (errorStr.contains('WireGuard')) {
      if (errorStr.contains('not found')) {
        return 'فایل‌های WireGuard یافت نشد. لطفا برنامه را دوباره نصب کنید.';
      }
      if (errorStr.contains('service')) {
        return 'خطا در راه‌اندازی سرویس VPN. لطفا با دسترسی مدیریت اجرا کنید.';
      }
      if (errorStr.contains('tunnel')) {
        return 'خطا در ایجاد تونل VPN. لطفا دوباره تلاش کنید.';
      }
    }

    // Registration errors
    if (errorStr.contains('Registration failed') || errorStr.contains('401') || errorStr.contains('403')) {
      return 'خطا در ثبت‌نام با سرور. لطفا بعدا تلاش کنید.';
    }

    // Permission errors
    if (errorStr.contains('permission') || errorStr.contains('access denied')) {
      return 'خطای دسترسی. لطفا برنامه را با دسترسی مدیریت اجرا کنید.';
    }

    // Generic connection errors
    if (errorStr.contains('Connection') || errorStr.contains('connect')) {
      return 'خطا در اتصال VPN. لطفا دوباره تلاش کنید.';
    }

    // Fallback
    if (errorStr.length > 100) {
      return 'خطای نامشخص. لطفا دوباره تلاش کنید.';
    }

    return errorStr.replaceFirst('Exception: ', '');
  }

  static void handleError(Object error, StackTrace? stackTrace, [String? context]) {
    final contextStr = context != null ? ' [$context]' : '';
    AppLogger.error('Error occurred$contextStr', error, stackTrace);
  }

  static Future<T?> tryCatch<T>(
    Future<T> Function() operation, {
    String? context,
    T? fallback,
    void Function(Object error)? onError,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      handleError(e, stackTrace, context);
      onError?.call(e);
      return fallback;
    }
  }
}

class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
  });

  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      attempt++;
      try {
        if (operationName != null && attempt > 1) {
          AppLogger.info('$operationName - Attempt $attempt/$maxAttempts');
        }
        return await operation();
      } catch (e) {
        final canRetry = shouldRetry?.call(e) ?? true;

        if (attempt >= maxAttempts || !canRetry) {
          AppLogger.error(
            '$operationName failed after $attempt attempts',
            e,
          );
          rethrow;
        }

        AppLogger.warning(
          '$operationName failed (attempt $attempt/$maxAttempts), retrying in ${delay.inSeconds}s',
        );

        await Future.delayed(delay);

        // Exponential backoff
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).toInt(),
        );
        if (delay > maxDelay) {
          delay = maxDelay;
        }
      }
    }
  }
}

class PerformanceMonitor {
  final Map<String, Stopwatch> _timers = {};

  void start(String operation) {
    _timers[operation] = Stopwatch()..start();
    AppLogger.debug('Started: $operation');
  }

  void stop(String operation) {
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      AppLogger.debug('Completed: $operation (${timer.elapsedMilliseconds}ms)');
      _timers.remove(operation);
    }
  }

  Future<T> measure<T>(String operation, Future<T> Function() action) async {
    start(operation);
    try {
      return await action();
    } finally {
      stop(operation);
    }
  }
}
