import 'package:digipad_flutter/screens/activation/cubit/activation_cubit.dart';
import 'package:digipad_flutter/screens/activation/data/activation_service.dart';
import 'package:digipad_flutter/screens/activation/presentation/activation_wrapper.dart';
import 'package:digipad_flutter/screens/activation/presentation/interaction_observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation app-wide
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    // App will likely fail if Firebase is required for activation
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.updateLocale(locale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  late final ActivationService _activationService;

  @override
  void initState() {
    super.initState();
    _activationService = ActivationService();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      setState(() {
        _locale = Locale(languageCode);
      });
    } else {
      // Default behavior (null) uses device locale
    }
  }

  void updateLocale(Locale locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    // Portait orientation is now handled in main()

    return BlocProvider(
      create: (context) => ActivationCubit(_activationService),
      child: InteractionObserver(
        child: MaterialApp(
          title: 'DigiTower 3D Premium',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          locale: _locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ActivationWrapper(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
