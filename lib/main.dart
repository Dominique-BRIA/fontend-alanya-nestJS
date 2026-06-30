import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/authed_api.dart';
import 'core/locale_controller.dart';
import 'core/push_service.dart';
import 'core/realtime_client.dart';
import 'core/token_storage.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/account/account_repository.dart';
import 'features/ai/ai_repository.dart';
import 'features/calls/call_controller.dart';
import 'features/calls/calls_repository.dart';
import 'features/chat/chat_repository.dart';
import 'features/contacts/contacts_repository.dart';
import 'features/home/home_screen.dart';
import 'features/media/media_repository.dart';
import 'features/status/status_repository.dart';
import 'theme/app_theme.dart';

void main() {
  final api = ApiClient();
  final storage = TokenStorage();
  final repo = AuthRepository(api);
  final authedApi = AuthedApi(api, storage);
  final realtime = RealtimeClient(storage);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<AuthRepository>.value(value: repo),
        Provider<TokenStorage>.value(value: storage),
        Provider<ContactsRepository>.value(value: ContactsRepository(authedApi)),
        Provider<ChatRepository>.value(value: ChatRepository(authedApi)),
        Provider<AccountRepository>.value(value: AccountRepository(authedApi)),
        Provider<StatusRepository>.value(value: StatusRepository(authedApi)),
        Provider<AiRepository>.value(value: AiRepository(authedApi)),
        Provider<MediaRepository>.value(value: MediaRepository(authedApi)),
        Provider<CallsRepository>.value(value: CallsRepository(authedApi)),
        ChangeNotifierProvider<RealtimeClient>.value(value: realtime),
        ChangeNotifierProvider<LocaleController>(
          create: (_) => LocaleController()..load(),
        ),
        ChangeNotifierProvider<CallController>(
          create: (ctx) => CallController(
            ctx.read<CallsRepository>(),
            ctx.read<RealtimeClient>(),
          ),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(repo, storage)..bootstrap(),
        ),
      ],
      child: const AlanyaApp(),
    ),
  );
}

class AlanyaApp extends StatelessWidget {
  const AlanyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeCtrl = context.watch<LocaleController>();
    return MaterialApp(
      navigatorKey: PushService.navigatorKey,
      title: "Alanya",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: localeCtrl.locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          backgroundColor: AppColors.cream,
          body: Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const WelcomeScreen();
    }
  }
}
