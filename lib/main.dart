import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/playlist_screen.dart';

void main() {
  // Ensure Flutter is initialized properly
  WidgetsFlutterBinding.ensureInitialized();

  // Log information about platform
  if (kDebugMode) {
    debugPrint('Running on platform: ${defaultTargetPlatform.toString()}');
    debugPrint('Is web: $kIsWeb');
  }

  runApp(const ProviderScope(child: AnimeThemesApp()));
}

class AnimeThemesApp extends StatelessWidget {
  const AnimeThemesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Anime Themes Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          surfaceContainer: const Color(0xFF121212),
          primary: Colors.blue.shade300,
          onPrimary: Colors.black,
          secondary: Colors.tealAccent.shade400,
          onSecondary: Colors.black,
        ),
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
        useMaterial3: true,
        sliderTheme: const SliderThemeData(
          thumbColor: Colors.blue,
          activeTrackColor: Colors.blue,
          inactiveTrackColor: Colors.grey,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF202020),
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 2.0,
        ),
      ),
      themeMode: ThemeMode.system,
    );
  }
}

// Define the router configuration
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/playlist',
      builder: (context, state) => const PlaylistScreen(),
    ),
  ],
);
