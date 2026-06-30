import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/back_app_bar.dart';
import '../../../widgets/motif_background.dart';
import '../../auth/auth_controller.dart';
import '../account_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _pseudoCtrl;
  late final TextEditingController _statusCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _pseudoCtrl = TextEditingController(text: user?.pseudo ?? "");
    _statusCtrl = TextEditingController(text: user?.statusMsg ?? "");
  }

  @override
  void dispose() {
    _pseudoCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pseudo = _pseudoCtrl.text.trim();
    if (pseudo.length < 2) {
      _snack("Le pseudo doit faire au moins 2 caractères");
      return;
    }
    setState(() => _saving = true);
    final account = context.read<AccountRepository>();
    final auth = context.read<AuthController>();
    try {
      final res = await account.updateProfile(
        pseudo: pseudo,
        statusMsg: _statusCtrl.text.trim(),
      );
      auth.applyProfile(pseudo: res.pseudo, statusMsg: res.statusMsg, avatarUrl: res.avatarUrl);
      _snack("Profil mis à jour");
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack("Mise à jour impossible");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return Scaffold(
      appBar: backAppBar(context, "Mon profil"),
      body: MotifBackground(
        overlayOpacity: 0.92,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.terracotta,
                  child: Text(
                    (user?.pseudo?.isNotEmpty ?? false) ? user!.pseudo![0].toUpperCase() : "?",
                    style: const TextStyle(color: Colors.white, fontSize: 34),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _infoCard(user?.publicNumber ?? "—", user?.email ?? "—"),
              const SizedBox(height: 20),
              TextField(
                controller: _pseudoCtrl,
                decoration: InputDecoration(
                  labelText: "Pseudo",
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _statusCtrl,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: "Statut (humeur, dispo…)",
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: const Text("Enregistrer"),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.read<AuthController>().logout(),
                icon: const Icon(Icons.logout),
                label: const Text("Se déconnecter"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String number, String email) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.tag, color: AppColors.terracotta),
              const SizedBox(width: 10),
              const Text("Numéro Alanya : ", style: TextStyle(color: Colors.black54)),
              Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.email_outlined, color: AppColors.clay),
              const SizedBox(width: 10),
              Expanded(child: Text(email, style: const TextStyle(color: Colors.black87))),
            ],
          ),
        ],
      ),
    );
  }
}
