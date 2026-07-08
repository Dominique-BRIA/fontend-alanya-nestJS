import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'call_controller.dart';
import 'screens/active_call_screen.dart';

/// Écoute les appels entrants et ouvre l'écran d'appel automatiquement.
class CallListener extends StatefulWidget {
  const CallListener({super.key, required this.child});
  final Widget child;

  @override
  State<CallListener> createState() => _CallListenerState();
}

class _CallListenerState extends State<CallListener> {
  bool _incomingRouteOpen = false;

  @override
  Widget build(BuildContext context) {
    final cc = context.watch<CallController>();
    if (cc.incoming != null) {
      debugPrint("[CallListener] cc.incoming n'est pas nul ! Ouverture de l'écran d'appel...");
    }
    if (cc.incoming != null && !_incomingRouteOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || cc.incoming == null) return;
        setState(() => _incomingRouteOpen = true);
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ActiveCallScreen(incoming: true),
          ),
        );
        if (mounted) setState(() => _incomingRouteOpen = false);
      });
    }
    return widget.child;
  }
}
