import 'package:anime_themes_media_player/models/audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

// Sample API response
const String sampleApiResponse = '''
{
  "anime": [
    {
      "id": "2028",
      "name": "Naruto",
      "media_format": "TV",
      "animethemes": [
        {
          "id": "101",
          "slug": "OP1",
          "type": "OP",
          "sequence": 1,
          "animethemeentries": [
            {
              "id": "789",
              "version": 1,
              "videos": [
                {
                  "id": "123",
                  "link": "https://v.animethemes.moe/Naruto-OP1.webm",
                  "audio": {
                    "id": "456",
                    "link": "https://a.animethemes.moe/Naruto-OP1.ogg",
                    "basename": "Naruto-OP1",
                    "filename": "Naruto Opening 1"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('Audio Player Tests with mocked API data', () {
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
    });

    test('Audio links from API parse correctly', () async {
      // Configure mock to return our sample response
      when(
        () => mockHttpClient.get(any()),
      ).thenAnswer((_) async => http.Response(sampleApiResponse, 200));

      // Make the API request with our mock client
      final response = await mockHttpClient.get(
        Uri.parse(
          'https://api.animethemes.moe/anime?q=Naruto&fields[anime]=id,name,media_format&include=images,animethemes.animethemeentries.videos.audio',
        ),
      );

      expect(response.statusCode, 200);

      final jsonData = json.decode(response.body);
      final List<String> audioLinks = [];

      // Extract audio links from the API response
      for (var anime in jsonData['anime']) {
        if (anime['animethemes'] != null) {
          for (var theme in anime['animethemes']) {
            if (theme['animethemeentries'] != null) {
              for (var entry in theme['animethemeentries']) {
                if (entry['videos'] != null) {
                  for (var video in entry['videos']) {
                    if (video['audio'] != null &&
                        video['audio']['link'] != null) {
                      audioLinks.add(video['audio']['link']);
                    }
                  }
                }
              }
            }
          }
        }
      }

      expect(audioLinks.length, greaterThan(0));

      // Verify the first audio link is a valid URL
      final audioUrl = audioLinks.first;
      expect(audioUrl, isA<String>());
      expect(audioUrl, contains('http'));
      expect(audioUrl, equals('https://a.animethemes.moe/Naruto-OP1.ogg'));
    });
  });

  group('Mock Audio Player Tests', () {
    late MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = MockAudioPlayer();
    });

    // Test audio playback control functions
    test('Play/Pause functionality', () {
      // Set up mocks
      when(() => mockPlayer.play()).thenAnswer((_) async {});
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      // Test play
      mockPlayer.play();
      verify(() => mockPlayer.play()).called(1);

      // Test pause
      mockPlayer.pause();
      verify(() => mockPlayer.pause()).called(1);
    });

    // Test seeking
    test('Seeking functionality', () {
      final testDuration = Duration(seconds: 60);
      final seekPosition = Duration(seconds: 30);

      // Set up mocks
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
      when(() => mockPlayer.duration).thenReturn(testDuration);

      // Test seeking
      mockPlayer.seek(seekPosition);
      verify(() => mockPlayer.seek(seekPosition)).called(1);
    });

    // Test playlist management
    test('Playlist navigation', () {
      final playlist = [
        Audio(id: '1', link: 'https://a.animethemes.moe/Naruto-OP1.ogg'),
        Audio(id: '2', link: 'https://a.animethemes.moe/Naruto-OP2.ogg'),
        Audio(id: '3', link: 'https://a.animethemes.moe/Naruto-OP3.ogg'),
      ];

      int currentIndex = 0;

      // Test next
      expect(currentIndex, 0);
      if (currentIndex < playlist.length - 1) {
        currentIndex++;
      }
      expect(currentIndex, 1);

      // Test previous
      if (currentIndex > 0) {
        currentIndex--;
      }
      expect(currentIndex, 0);

      // Test jump to specific index
      currentIndex = 2;
      expect(currentIndex, 2);

      // Test bounds checking
      if (currentIndex >= playlist.length) {
        currentIndex = playlist.length - 1;
      }
      expect(currentIndex, 2);
    });

    // Test loading audio source
    test('Loading audio source', () {
      final audioUrl = 'https://a.animethemes.moe/Naruto-OP1.ogg';

      // Set up mock
      when(
        () => mockPlayer.setUrl(any()),
      ).thenAnswer((_) async => Duration(seconds: 90));

      // Test loading audio
      mockPlayer.setUrl(audioUrl);
      verify(() => mockPlayer.setUrl(audioUrl)).called(1);
    });
  });
}
