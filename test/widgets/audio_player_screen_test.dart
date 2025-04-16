import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
// Add missing imports
import 'package:anime_themes_media_player/models/audio.dart';
import 'package:anime_themes_media_player/screens/audio_player_screen.dart';

// Define mocks
class MockAudioPlayer extends Mock {}

void main() {
  group('AudioPlayerScreen Tests', () {
    // Test audio object
    final testAudio = Audio(
      id: 'test-audio-id',
      link: 'https://cdn.animethemes.moe/audio/CowboyBebop-OP1.ogg',
      filename: 'Test Audio File',
      basename: 'Test Audio',
    );

    testWidgets('AudioPlayerScreen initializes without crashing', (
      WidgetTester tester,
    ) async {
      // Build our screen inside a material app with provider scope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AudioPlayerScreen(initialAudio: testAudio, isPlaylist: false),
          ),
        ),
      );

      // Initial build should complete without errors
      await tester.pump(const Duration(milliseconds: 300));

      // The app bar title should be "Now Playing"
      expect(find.text('Now Playing'), findsOneWidget);

      // The audio title should be present
      expect(find.text('Test Audio'), findsOneWidget);
    });

    testWidgets('Playlist mode shows playlist controls', (
      WidgetTester tester,
    ) async {
      // Build our screen inside a material app with provider scope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AudioPlayerScreen(
              initialAudio: testAudio,
              isPlaylist: true, // Force playlist mode through prop
            ),
          ),
        ),
      );

      // Allow time for widgets to build
      await tester.pump(const Duration(milliseconds: 300));

      // In playlist mode, we expect to find play/pause controls
      expect(find.byIcon(Icons.play_circle_filled), findsAtLeastNWidgets(1));
    });

    testWidgets('Play/pause button is present', (WidgetTester tester) async {
      // Build our screen inside a material app with provider scope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AudioPlayerScreen(initialAudio: testAudio, isPlaylist: false),
          ),
        ),
      );

      // Allow time for widgets to build
      await tester.pump(const Duration(milliseconds: 300));

      // We should see play/pause buttons (either play_circle_filled or pause_circle_filled)
      expect(find.byIcon(Icons.play_circle_filled), findsAtLeastNWidgets(1));
    });

    testWidgets('Playlist button is present in app bar', (
      WidgetTester tester,
    ) async {
      // Build our screen inside a material app with provider scope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AudioPlayerScreen(initialAudio: testAudio, isPlaylist: false),
          ),
        ),
      );

      // Allow time for widgets to build
      await tester.pump(const Duration(milliseconds: 300));

      // Find playlist button in the app bar
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
    });
  });
}
