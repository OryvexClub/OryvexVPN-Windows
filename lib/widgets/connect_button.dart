import 'package:flutter/material.dart';
import '../constants/strings.dart';
import '../theme/app_theme.dart';

class ConnectButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isConnected, isConnecting;
  const ConnectButton({super.key, this.onPressed, required this.isConnected, required this.isConnecting});
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: isConnected ? AppTheme.error : AppTheme.success,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (isConnecting) const SizedBox(height:24,width:24,child: CircularProgressIndicator(strokeWidth:2,valueColor:AlwaysStoppedAnimation<Color>(Colors.white)))
      else Icon(isConnected ? Icons.power_settings_new : Icons.power_settings_new_outlined, size:28),
      const SizedBox(width:12),
      Text(isConnected ? Strings.disconnect : (isConnecting ? Strings.connecting : Strings.connect), style: const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    ]),
  ));
}
