import 'package:flutter/material.dart';
import '../main.dart';

void _showConflictModal(List<String> procs, BuildContext context, Function onKillAll) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Conflicting Programs Detected'),
      content: Text('The following programs might conflict with the VPN:\n\n${procs.join(', ')}\n\nPlease close them to continue.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            // Ignore logic
          },
          child: const Text('Ignore'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onKillAll();
          },
          child: const Text('Kill All', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void _showClockModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('System Clock Error'),
      content: const Text('Your system clock is not synchronized. This will prevent the VPN from connecting properly. Please sync your Windows clock.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
