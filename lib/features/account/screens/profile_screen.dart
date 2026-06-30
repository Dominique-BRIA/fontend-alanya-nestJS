import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
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
      _snack(tr(context, 'pseudo_min_2'));
      return;
    }
    setState(() => _saving = true);
    final account = context.read<AccountRepository>();
    final auth = context.read<AuthController>();
    try {
      final res = await account.updateProfile(pseudo: pseudo, statusMsg: _statusCtrl.text.trim());
      auth.applyProfile(pseudo: res.pseudo, statusMsg: res.statusMsg, avatarUrl: res.avatarUrl);
      _snack(tr(context, 'profile_updated'));
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(tr(context, 'profile_update_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final localeCtrl = context.watch<LocaleController>();
    return Scaffold(
      appBar: backAppBar(context, tr(context, 'my_profile')),
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
                  child: Text((user?.pseudo?.isNotEmpty ?? false) ? user!.pseudo![0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontSize: 34)),
                ),
              ),
              const SizedBox(height: 16),
              _infoCard(user?.publicNumber ?? "—", user?.email ?? "—"),
              const SizedBox(height: 20),
              TextField(controller: _pseudoCtrl, decoration: InputDecoration(labelText: tr(context, 'pseudo'), prefixIcon: const Icon(Icons.person))),
              const SizedBox(height: 14),
              TextField(controller: _statusCtrl, maxLength: 255, decoration: InputDecoration(labelText: tr(context, 'status_hint'), prefixIcon: const Icon(Icons.info_outline))),
              const SizedBox(height: 8),
              ElevatedButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(tr(context, 'save'))),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.sand)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.language, color: AppColors.forest), const SizedBox(width: 10), Text(tr(context, 'language_settings'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))]),
                  const SizedBox(height: 8),
                  Text(tr(context, 'language_description'), style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'fr', label: Text(tr(context, 'french')), icon: const Text('🇫🇷')),
                      ButtonSegment(value: 'en', label: Text(tr(context, 'english')), icon: const Text('🇬🇧')),
                    ],
                    selected: {localeCtrl.languageCode},
                    onSelectionChanged: (s) => localeCtrl.setLocale(s.first),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(onPressed: () => context.read<AuthController>().logout(), icon: const Icon(Icons.logout), label: Text(tr(context, 'logout'))),
            ],
          ),
        ),
      ),
    );
  }
  Widget _infoCard(String number, String email) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.sand)),
      child: Column(children: [
        Row(children: [const Icon(Icons.tag, color: AppColors.terracotta), const SizedBox(width: 10), Text(tr(context, 'alanya_number_label'), style: const TextStyle(color: Colors.black54)), Text(number, style: const TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        Row(children: [const Icon(Icons.email_outlined, color: AppColors.clay), const SizedBox(width: 10), Expanded(child: Text(email, style: const TextStyle(color: Colors.black87)))]),
      ]),
    );
  }
}
