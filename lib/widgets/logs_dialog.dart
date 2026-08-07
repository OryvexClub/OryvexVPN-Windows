import 'dart:async';
import 'package:flutter/material.dart';
import '../services/oryvex_service.dart';
import '../services/xray_service.dart';

/// A dialog that displays real-time logs from oryvex and xray core processes.
class LogsDialog extends StatefulWidget {
  const LogsDialog({super.key});

  @override
  State<LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends State<LogsDialog> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _oryvexSubscription;
  StreamSubscription<String>? _xraySubscription;

  @override
  void initState() {
    super.initState();
    // Load recent logs from both services
    _logs.addAll(OryvexService.recentLogs);
    _logs.addAll(XrayService.recentLogs);
    // Sort by timestamp (they're formatted with [HH:mm:ss])
    _logs.sort((a, b) {
      final aTime = a.substring(0, 10);
      final bTime = b.substring(0, 10);
      return aTime.compareTo(bTime);
    });

    // Subscribe to real-time log streams
    _oryvexSubscription = OryvexService.logStream.listen((line) {
      if (mounted) {
        setState(() {
          _logs.add(line);
          if (_logs.length > 500) _logs.removeAt(0);
        });
        _scrollToBottom();
      }
    });

    _xraySubscription = XrayService.logStream.listen((line) {
      if (mounted) {
        setState(() {
          _logs.add(line);
          if (_logs.length > 500) _logs.removeAt(0);
        });
        _scrollToBottom();
      }
    });

    // Scroll to bottom after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _oryvexSubscription?.cancel();
    _xraySubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Color _getLineColor(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('ERROR') || upper.contains('EXCEPTION')) {
      return const Color(0xFFFF3366); // Red
    } else if (upper.contains('WARN')) {
      return const Color(0xFFFFB800); // Yellow
    } else if (upper.contains('INFO') || upper.contains('[+]')) {
      return const Color(0xFF00E5FF); // Cyan
    }
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF222222)),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF222222)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: Color(0xFF00E5FF), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'CORE LOGS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  // Clear button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _logs.clear();
                      });
                      OryvexService.clearLogs();
                      XrayService.clearLogs();
                    },
                    child: const Text(
                      'CLEAR',
                      style: TextStyle(
                        color: Color(0xFF888891),
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF888891), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Log content
            Expanded(
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs yet. Connect to see core output.',
                        style: TextStyle(color: Color(0xFF888891), fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final line = _logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            line,
                            style: TextStyle(
                              color: _getLineColor(line),
                              fontFamily: 'Consolas',
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
