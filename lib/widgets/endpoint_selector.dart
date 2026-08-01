import 'package:flutter/material.dart';
import '../services/warp_generator.dart';
import '../constants/strings.dart';
class EndpointSelector extends StatefulWidget {
  final Function(String ip, String port) onEndpointSelected;
  const EndpointSelector({super.key, required this.onEndpointSelected});
  @override
  _EndpointSelectorState createState() => _EndpointSelectorState();
}
class _EndpointSelectorState extends State<EndpointSelector> {
  bool _useCustom = false;
  String _selectedIp = '', _selectedPort = '';
  final TextEditingController _ipController = TextEditingController(), _portController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Icon(Icons.route, color: Color(0xFF10B981)),
      const SizedBox(width:8),
      Text(Strings.endpoint, style: const TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:Colors.white)),
      const Spacer(),
      IconButton(icon: const Icon(Icons.shuffle, color: Color(0xFF10B981)), onPressed: () {
        final endpoint = WARPGenerator.getRandomEndpoint();
        final ip = endpoint['ip']!, port = endpoint['port']!;
        widget.onEndpointSelected(ip, port);
        setState(() { _selectedIp = ip; _selectedPort = port; _useCustom = true; _ipController.text = ip; _portController.text = port; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${Strings.randomIP}: $ip:$port'), backgroundColor: const Color(0xFF10B981)));
      }),
    ]),
    const SizedBox(height:12),
    Row(children: [
      Expanded(child: DropdownButtonFormField<bool>(
        value: _useCustom,
        style: const TextStyle(color: Colors.white),
        dropdownColor: const Color(0xFF1A1A1A),
        items: const [DropdownMenuItem(value:false, child: Text(Strings.auto)), DropdownMenuItem(value:true, child: Text(Strings.custom))],
        onChanged: (value) { setState(() { _useCustom = value!; if (!_useCustom) { _selectedIp=''; _selectedPort=''; _ipController.clear(); _portController.clear(); widget.onEndpointSelected('',''); } }); },
        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981)))),
      )),
    ]),
    if (_useCustom) ...[
      const SizedBox(height:12),
      Row(children: [
        Expanded(flex:2, child: TextField(controller: _ipController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: Strings.ipAddress, labelStyle: TextStyle(color: Colors.grey[400]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981)))))),
        const SizedBox(width:8),
        Expanded(child: TextField(controller: _portController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: Strings.port, labelStyle: TextStyle(color: Colors.grey[400]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[800]!)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981)))))),
        const SizedBox(width:8),
        ElevatedButton(onPressed: () { final ip = _ipController.text.trim(); final port = _portController.text.trim(); if (ip.isNotEmpty && port.isNotEmpty) { widget.onEndpointSelected(ip, port); setState(() { _selectedIp = ip; _selectedPort = port; }); } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal:16, vertical:14)), child: Text(Strings.apply)),
      ]),
      if (_selectedIp.isNotEmpty) ...[
        const SizedBox(height:8),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: Row(children: [const Icon(Icons.check_circle, color: Color(0xFF10B981), size:16), const SizedBox(width:8), Text('${Strings.selected}: $_selectedIp:$_selectedPort', style: const TextStyle(color: Color(0xFF10B981), fontSize:13, fontWeight:FontWeight.w500))])),
      ],
    ],
  ])));
}
