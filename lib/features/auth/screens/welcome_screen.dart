import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/motif_background.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Écran d'accueil : logo Alanya sur fond motif + boutons S'inscrire / Se connecter.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MotifBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Image.asset(
                  "assets/images/logo.png",
                  width: 280,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.chat_bubble_rounded,
                    size: 120,
                    color: AppColors.terracotta,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Discutez, appelez, partagez — en toute simplicité.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.ink),
                ),
                const Spacer(flex: 3),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: const Text("Créer un compte"),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.terracotta),
                    foregroundColor: AppColors.terracotta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text("J'ai déjà un compte"),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
