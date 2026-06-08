import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_snackbar.dart';
import '../../../models/contact.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/back_app_bar.dart';
import '../../chat/chat_repository.dart';
import '../../chat/screens/chat_screen.dart';
import '../contacts_repository.dart';

/// Recherche d'un utilisateur par numéro public à 6 chiffres, puis démarrage d'une discussion.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _numberCtrl = TextEditingController();
  bool _loading = false;
  UserSearchResult? _result;
  String? _error;

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final number = _numberCtrl.text.trim();
    if (number.length != 6) {
      setState(() => _error = "Entre un numéro à 6 chiffres");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await context.read<ContactsRepository>().searchByNumber(number);
      setState(() => _result = res);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Recherche impossible");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChat(UserSearchResult user) async {
    setState(() => _loading = true);
    final contacts = context.read<ContactsRepository>();
    final chat = context.read<ChatRepository>();
    try {
      if (!user.alreadyContact) {
        await contacts.add(user.publicNumber);
      }
      final convId = await chat.createDirect(user.publicNumber);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(convId: convId, title: user.pseudo ?? user.publicNumber),
        ),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError("Impossible de démarrer la discussion");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String m) => showAppSnackBar(m);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: backAppBar(context, "Nouvelle discussion"),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Recherche par numéro Alanya",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text("Saisis le numéro public à 6 chiffres de ton contact.",
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numberCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: "Numéro (6 chiffres)",
                        counterText: "",
                        prefixIcon: Icon(Icons.tag),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _search,
                      child: const Icon(Icons.search),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
              if (_result != null) _resultCard(_result!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultCard(UserSearchResult user) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.sand),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.clay,
          child: Text((user.pseudo ?? "?")[0].toUpperCase(),
              style: const TextStyle(color: Colors.white)),
        ),
        title: Text(user.pseudo ?? "Utilisateur ${user.publicNumber}"),
        subtitle: Text("Numéro : ${user.publicNumber}"),
        trailing: ElevatedButton(
          onPressed: _loading ? null : () => _startChat(user),
          child: const Text("Discuter"),
        ),
      ),
    );
  }
}
