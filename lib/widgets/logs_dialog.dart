import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/oryvex_service.dart';
import '../services/xray_service.dart';
import '../theme/app_theme.dart';

/// A dialog that displays real-time logs from oryvex and xray core processes.
class LogsDialog extends StatefulWidget {
  const LogsDialog({super.key});

  @override
  State<LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends State<LogsDialog> {
  final List<String> _logs = [];
  final List<String> _filteredLogs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _oryvexSubscription;
  StreamSubscription<String>? _xraySubscription;

  bool _autoScroll = true;
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load recent logs from both services
    _logs.addAll(OryvexService.recentLogs);
    _logs.addAll(XrayService.recentLogs);
    // Sort by timestamp (they're formatted with [HH:mm:ss])
    _logs.sort((a, b) {
      final aTime = a.length >= 10 ? a.substring(0, 10) : '';
      final bTime = b.length >= 10 ? b.substring(0, 10) : '';
      return aTime.compareTo(bTime);
    });
    _updateFilteredLogs();

    // Subscribe to real-time log streams
    _oryvexSubscription = OryvexService.logStream.listen((line) {
      if (mounted) {
        setState(() {
          _logs.add(line);
          if (_logs.length > 500) _logs.removeAt(0);
          _updateFilteredLogs();
        });
        if (_autoScroll) _scrollToBottom();
      }
    });

    _xraySubscription = XrayService.logStream.listen((line) {
      if (mounted) {
        setState(() {
          _logs.add(line);
          if (_logs.length > 500) _logs.removeAt(0);
          _updateFilteredLogs();
        });
        if (_autoScroll) _scrollToBottom();
      }
    });

    // Scroll to bottom after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(instant: true);
    });
  }

  @override
  void dispose() {
    _oryvexSubscription?.cancel();
    _xraySubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredLogs() {
    if (_searchQuery.isEmpty) {
      _filteredLogs.addAll(_logs);
    } else {
      _filteredLogs.clear();
      final query = _searchQuery.toLowerCase();
      for (final log in _logs) {
        if (log.toLowerCase().contains(query)) {
          _filteredLogs.add(log);
        }
      }
    }
  }

  void _scrollToBottom({bool instant = false}) {
    if (_scrollController.hasClients) {
      if (instant) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScroll = !_autoScroll;
      if (_autoScroll) _scrollToBottom();
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchQuery = '';
        _searchController.clear();
        _filteredLogs.clear();
        _filteredLogs.addAll(_logs);
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredLogs.clear();
      if (query.isEmpty) {
        _filteredLogs.addAll(_logs);
      } else {
        final lowerQuery = query.toLowerCase();
        for (final log in _logs) {
          if (log.toLowerCase().contains(lowerQuery)) {
            _filteredLogs.add(log);
          }
        }
      }
    });
  }

  Color _getLineColor(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('ERROR') || upper.contains('EXCEPTION')) {
      return AppTheme.error;
    } else if (upper.contains('WARN')) {
      return AppTheme.warning;
    } else if (upper.contains('INFO') || upper.contains('[+]')) {
      return AppTheme.accent;
    }
    return AppTheme.textDim;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight),
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
                border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: AppTheme.accent, size: 20),
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
                  // Search count
                  if (_showSearch && _searchQuery.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_filteredLogs.length} matches',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_showSearch && _searchQuery.isNotEmpty)
                    const SizedBox(width: 8),
                  // Auto-scroll toggle
                  IconButton(
                    onPressed: _toggleAutoScroll,
                    icon: Icon(
                      _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top,
                      color: _autoScroll ? AppTheme.accent : AppTheme.textSecondary,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                    tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
                  ),
                  // Search toggle
                  IconButton(
                    onPressed: _toggleSearch,
                    icon: Icon(
                      Icons.search,
                      color: _showSearch ? AppTheme.accent : AppTheme.textSecondary,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                    tooltip: 'Search logs',
                  ),
                  // Clear button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _logs.clear();
                        _filteredLogs.clear();
                      });
                      OryvexService.clearLogs();
                      XrayService.clearLogs();
                    },
                    child: const Text(
                      'CLEAR',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Copy button
                  TextButton(
                    onPressed: () {
                      final text = _logs.join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Logs copied to clipboard'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.surfaceOverlay,
                        ),
                      );
                    },
                    child: const Text(
                      'COPY',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Search bar (toggleable)
            if (_showSearch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'Consolas',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            // Log content
            Expanded(
              child: _filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.terminal,
                            color: AppTheme.textTertiary,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No logs match "$_searchQuery"'
                                : 'No logs yet. Connect to see core output.',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final line = _filteredLogs[index];
                        return _buildLogLine(line);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogLine(String line) {
    // Parse timestamp prefix [HH:mm:ss] and render it in a different color
    final timestampMatch = RegExp(r'^\[[\d:]+\]').firstMatch(line);

    if (timestampMatch != null) {
      final timestamp = timestampMatch.group(0)!;
      final rest = line.substring(timestamp.length);
      final lineColor = _getLineColor(line);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: timestamp,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: rest,
                style: TextStyle(
                  color: lineColor,
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line,
        style: TextStyle(
          color: _getLineColor(line),
          fontFamily: 'Consolas',
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}
