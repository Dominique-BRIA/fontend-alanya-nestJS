import 'package:flutter/widgets.dart';
import '../core/locale_controller.dart';
import 'package:provider/provider.dart';

class AppLocalizations {
  final String languageCode;
  AppLocalizations(this.languageCode);

  static AppLocalizations of(BuildContext context) {
    final localeCtrl = context.watch<LocaleController>();
    return AppLocalizations(localeCtrl.languageCode);
  }

  static AppLocalizations read(BuildContext context) {
    final localeCtrl = context.read<LocaleController>();
    return AppLocalizations(localeCtrl.languageCode);
  }

  String get(String key) => _localizedValues[languageCode]?[key] ?? _localizedValues['fr']?[key] ?? key;

  static const _localizedValues = <String, Map<String, String>>{
    'fr': {
      // Welcome
      'app_tagline': 'Discutez, appelez, partagez — en toute simplicité.',
      'create_account': 'Créer un compte',
      'have_account': "J'ai déjà un compte",
      'language': 'Langue',
      'french': 'Français',
      'english': 'English',
      // Auth
      'login': 'Connexion',
      'login_welcome': 'Content de te revoir 👋',
      'email_or_alanya': 'Email ou numéro Alanya (6 chiffres)',
      'password': 'Mot de passe',
      'sign_in': 'Se connecter',
      'register': 'Créer un compte',
      'register_question': 'Quel est ton email ?',
      'register_hint': "Nous t'enverrons un code de confirmation à 6 chiffres.",
      'email': 'Email',
      'email_required': 'Email requis',
      'email_invalid': 'Email invalide',
      'receive_code': 'Recevoir le code',
      'confirmation': 'Confirmation',
      'enter_code': 'Entre le code reçu',
      'code_sent_to': 'Un code à 6 chiffres a été envoyé à {email}.',
      'verify': 'Vérifier',
      'resend_code': 'Renvoyer le code',
      'enter_6_digits': 'Entre les 6 chiffres du code.',
      'new_code_sent': 'Nouveau code envoyé.',
      'profile_setup': 'Ton profil',
      'alanya_number': 'Ton numéro Alanya',
      'alanya_number_help': "C'est avec ce numéro que tes contacts te trouveront.",
      'pseudo': 'Pseudo',
      'password_min_8': '8 caractères minimum',
      'finish': 'Terminer',
      'server_unreachable': 'Impossible de contacter le serveur.',
      // Home / tabs
      'chats': 'Discussions',
      'status': 'Statuts',
      'calls': 'Appels',
      'contacts': 'Contacts',
      // Chat
      'write_message': 'Écrire un message…',
      'attach_file': 'Joindre un fichier',
      'recording_hold': 'Enregistrement… relâche pour envoyer',
      'voice_message': 'Message vocal',
      'download': 'Télécharger',
      'file': 'Fichier',
      'no_messages': 'Aucun message. Dis bonjour 👋',
      'send_failed': 'Envoi impossible',
      'micro_unavailable': 'Microphone inaccessible',
      'micro_unavailable_platform': 'Micro non disponible sur cette plateforme — joins un fichier audio via 📎',
      'file_picker_linux': 'Sélection de fichier indisponible sur Linux — installe zenity : sudo apt install zenity',
      // Translate
      'translate': 'Traduire',
      'translating': 'Traduction…',
      'translation_failed': 'Traduction impossible',
      'translated': 'Traduction',
      'show_original': 'Voir l\'original',
      'original': 'Original',
      // Profile
      'my_profile': 'Mon profil',
      'alanya_number_label': 'Numéro Alanya : ',
      'status_hint': 'Statut (humeur, dispo…)',
      'save': 'Enregistrer',
      'logout': 'Se déconnecter',
      'profile_updated': 'Profil mis à jour',
      'profile_update_failed': 'Mise à jour impossible',
      'pseudo_min_2': 'Le pseudo doit faire au moins 2 caractères',
      'language_settings': 'Langue de l’application',
      'language_description': 'Choisis la langue d’affichage pour Alanya.',
      // Calls
      'audio_call': 'Appel audio',
      'video_call': 'Appel vidéo',
      'end_call': 'Raccrocher',
      'incoming_call': 'Appel entrant…',
      'accept': 'Accepter',
      'decline': 'Refuser',
      // Contacts
      'new_chat': 'Nouvelle discussion',
      'add_contact': 'Ajouter un contact',
      'search_alanya': 'Recherche par numéro Alanya',
      'contacts_on_alanya': 'Contacts',
      // Misc
      'cancel': 'Annuler',
      'close': 'Fermer',
      'ok': 'OK',
      'loading': 'Chargement…',
      'retry': 'Réessayer',
      'error': 'Erreur',
    },
    'en': {
      // Welcome
      'app_tagline': 'Chat, call, share — simply.',
      'create_account': 'Create an account',
      'have_account': 'I already have an account',
      'language': 'Language',
      'french': 'Français',
      'english': 'English',
      // Auth
      'login': 'Login',
      'login_welcome': 'Welcome back 👋',
      'email_or_alanya': 'Email or Alanya number (6 digits)',
      'password': 'Password',
      'sign_in': 'Sign in',
      'register': 'Create account',
      'register_question': 'What is your email?',
      'register_hint': 'We will send you a 6-digit confirmation code.',
      'email': 'Email',
      'email_required': 'Email required',
      'email_invalid': 'Invalid email',
      'receive_code': 'Receive code',
      'confirmation': 'Confirmation',
      'enter_code': 'Enter the code you received',
      'code_sent_to': 'A 6-digit code was sent to {email}.',
      'verify': 'Verify',
      'resend_code': 'Resend code',
      'enter_6_digits': 'Enter the 6 digits of the code.',
      'new_code_sent': 'New code sent.',
      'profile_setup': 'Your profile',
      'alanya_number': 'Your Alanya number',
      'alanya_number_help': 'This is the number your contacts will use to find you.',
      'pseudo': 'Username',
      'password_min_8': '8 characters minimum',
      'finish': 'Finish',
      'server_unreachable': 'Unable to reach the server.',
      // Home / tabs
      'chats': 'Chats',
      'status': 'Status',
      'calls': 'Calls',
      'contacts': 'Contacts',
      // Chat
      'write_message': 'Write a message…',
      'attach_file': 'Attach a file',
      'recording_hold': 'Recording… release to send',
      'voice_message': 'Voice message',
      'download': 'Download',
      'file': 'File',
      'no_messages': 'No messages yet. Say hi 👋',
      'send_failed': 'Failed to send',
      'micro_unavailable': 'Microphone unavailable',
      'micro_unavailable_platform': 'Microphone not available on this platform — attach an audio file via 📎',
      'file_picker_linux': 'File picker unavailable on Linux — install zenity: sudo apt install zenity',
      // Translate
      'translate': 'Translate',
      'translating': 'Translating…',
      'translation_failed': 'Translation failed',
      'translated': 'Translation',
      'show_original': 'Show original',
      'original': 'Original',
      // Profile
      'my_profile': 'My profile',
      'alanya_number_label': 'Alanya number: ',
      'status_hint': 'Status (mood, availability…)',
      'save': 'Save',
      'logout': 'Log out',
      'profile_updated': 'Profile updated',
      'profile_update_failed': 'Update failed',
      'pseudo_min_2': 'Username must be at least 2 characters',
      'language_settings': 'App language',
      'language_description': 'Choose the display language for Alanya.',
      // Calls
      'audio_call': 'Audio call',
      'video_call': 'Video call',
      'end_call': 'Hang up',
      'incoming_call': 'Incoming call…',
      'accept': 'Accept',
      'decline': 'Decline',
      // Contacts
      'new_chat': 'New chat',
      'add_contact': 'Add contact',
      'search_alanya': 'Search by Alanya number',
      'contacts_on_alanya': 'Contacts',
      // Misc
      'cancel': 'Cancel',
      'close': 'Close',
      'ok': 'OK',
      'loading': 'Loading…',
      'retry': 'Retry',
      'error': 'Error',
    },
  };
}

/// Helper shortcut: tr(context, 'key')
String tr(BuildContext context, String key, [Map<String, String>? params]) {
  final loc = AppLocalizations.of(context);
  var s = loc.get(key);
  if (params != null) {
    params.forEach((k, v) {
      s = s.replaceAll('{$k}', v);
    });
  }
  return s;
}
