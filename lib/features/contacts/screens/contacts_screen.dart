import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_snackbar.dart';
import '../../../models/contact.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/back_app_bar.dart';
import '../../../widgets/motif_background.dart';
import '../../chat/chat_repository.dart';
import '../../chat/screens/chat_screen.dart';
import '../contacts_repository.dart';
import 'add_contact_screen.dart';
import 'new_chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact>? _contacts;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<ContactsRepository>().list();
      if (!mounted) return;
      setState(() {
        _contacts = list;
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _startChat(Contact c) async {
    final chat = context.read<ChatRepository>();
    try {
      final convId = await chat.createDirect(c.publicNumber);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(convId: convId, title: c.displayName)),
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack("Impossible d'ouvrir la discussion");
    }
  }

  Future<void> _toggleBlock(Contact c) async {
    try {
      await context.read<ContactsRepository>().setBlocked(c.id, !c.isBlocked);
      await _load();
    } catch (_) {
      _snack("Action impossible");
    }
  }

  Future<void> _remove(Contact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer le contact ?"),
        content: Text("${c.displayName} sera retiré de ton répertoire."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<ContactsRepository>().remove(c.id);
      await _load();
    } catch (_) {
      _snack("Suppression impossible");
    }
  }

  void _snack(String m) => showAppSnackBar(m);

  Future<void> _openAddContact() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddContactScreen()),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: backAppBar(
        context,
        "Contacts",
        actions: [
          IconButton(
            tooltip: "Nouvelle discussion",
            icon: const Icon(Icons.chat_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewChatScreen()),
              );
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Ajouter un contact",
        backgroundColor: AppColors.forest,
        onPressed: _openAddContact,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: MotifBackground(
        overlayOpacity: 0.92,
        child: RefreshIndicator(onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_contacts == null && !_error) {
      return const Center(child: CircularProgressIndicator(color: AppColors.terracotta));
    }
    if (_error) {
      return ListView(children: const [
        SizedBox(height: 80),
        Center(child: Text("Erreur de chargement. Tire pour réessayer.")),
      ]);
    }
    final contacts = _contacts ?? [];
    if (contacts.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 100),
        Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Aucun contact.\nAjoute quelqu'un via son numéro Alanya à 6 chiffres.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      ]);
    }
    return ListView.separated(
      itemCount: contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _tile(contacts[i]),
    );
  }

  Widget _tile(Contact c) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: c.isBlocked ? Colors.grey : AppColors.clay,
        child: Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : "?",
            style: const TextStyle(color: Colors.white)),
      ),
      title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text("Numéro : ${c.publicNumber}${c.isBlocked ? " · bloqué" : ""}"),
      onTap: c.isBlocked ? null : () => _startChat(c),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == "chat") _startChat(c);
          if (v == "block") _toggleBlock(c);
          if (v == "delete") _remove(c);
        },
        itemBuilder: (_) => [
          if (!c.isBlocked) const PopupMenuItem(value: "chat", child: Text("Discuter")),
          PopupMenuItem(value: "block", child: Text(c.isBlocked ? "Débloquer" : "Bloquer")),
          const PopupMenuItem(value: "delete", child: Text("Supprimer")),
        ],
      ),
    );
  }
}
