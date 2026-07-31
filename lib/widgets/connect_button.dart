import 'package:flutter/material.dart';
import '../constants/strings.dart';
class ConnectButton extends StatelessWidget {
  final VoidCallback? onPressed; final bool isConnected, isConnecting;
  const ConnectButton({Key? key, this.onPressed, required this.isConnected, required this.isConnecting}) : super(key: key);
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: isConnected ? Colors.red : const Color(0xFF10B981),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (isConnecting) const SizedBox(height:24,width:24,child: CircularProgressIndicator(strokeWidth:2,valueColor:AlwaysStoppedAnimation<Color>(Colors.white)))
      else Icon(isConnected ? Icons.power_settings_new : Icons.power_settings_new, size:28),
      const SizedBox(width:12),
      Text(isConnected ? Strings.disconnect : (isConnecting ? Strings.connecting : Strings.connect), style: const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    ]),
  ));
}
