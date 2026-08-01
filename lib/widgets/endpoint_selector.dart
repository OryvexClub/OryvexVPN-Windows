import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/strings.dart';

class EndpointSelector extends StatefulWidget {
  final void Function(String ip, String port) onEndpointSelected;

  const EndpointSelector({super.key, required this.onEndpointSelected});

  @override
  State<EndpointSelector> createState() => _EndpointSelectorState();
}

class _EndpointSelectorState extends State<EndpointSelector> {
  static const List<String> _endpoints = [
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "162.159.195.1", "162.159.195.2", "162.159.195.5",
    "188.114.96.0", "188.114.96.1", "188.114.96.2", "188.114.96.3",
    "188.114.96.4", "188.114.96.5", "188.114.97.0", "188.114.97.1",
    "188.114.97.2", "188.114.97.3", "188.114.97.4", "188.114.97.5",
    "188.114.98.0", "188.114.98.1", "188.114.98.2", "188.114.99.0",
    "188.114.99.1", "188.114.99.2",
  ];
  static const String _defaultPort = '2408';

  final Random _random = Random();
  bool _useCustom = false;
  String _selectedIp = '';
  String _selectedPort = '';

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Map<String, String> _pickRandomEndpoint() {
    final ip = _endpoints[_random.nextInt(_endpoints.length)];
    return {'ip': ip, 'port': _defaultPort};
  }

  void _applyEndpoint(String ip, String port) {
    widget.onEndpointSelected(ip, port);
    setState(() {
      _selectedIp = ip;
      _selectedPort = port;
      _useCustom = true;
      _ipController.text = ip;
      _portController.text = port;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  Strings.endpoint,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.shuffle, color: Color(0xFF10B981)),
                  tooltip: Strings.randomIP,
                  onPressed: () {
                    final endpoint = _pickRandomEndpoint();
                    _applyEndpoint(endpoint['ip']!, endpoint['port']!);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    value: _useCustom,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1A1A1A),
                    items: const [
                      DropdownMenuItem(value: false, child: Text(Strings.auto)),
                      DropdownMenuItem(value: true, child: Text(Strings.custom)),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _useCustom = value ?? false;
                        if (!_useCustom) {
                          _selectedIp = '';
                          _selectedPort = '';
                          _ipController.clear();
                          _portController.clear();
                          widget.onEndpointSelected('', '');
                        }
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
