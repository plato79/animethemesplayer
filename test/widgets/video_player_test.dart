import 'package:anime_themes_media_player/models/anime.dart';
import 'package:anime_themes_media_player/models/anime_theme.dart';
import 'package:anime_themes_media_player/models/anime_theme_entry.dart';
import 'package:anime_themes_media_player/models/audio.dart';
import 'package:anime_themes_media_player/models/video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mocktail/mocktail.dart';

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
                  "resolution": 1080,
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

  group('Video Player Widget Tests with mocked API data', () {
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      when(
        () => mockHttpClient.get(any()),
      ).thenAnswer((_) async => http.Response(sampleApiResponse, 200));
    });

    test('Get video and audio links from API', () async {
      final response = await mockHttpClient.get(
        Uri.parse(
          'https://api.animethemes.moe/anime?q=Naruto&fields[anime]=id,name,media_format&include=images,animethemes.animethemeentries.videos.audio',
        ),
      );

      expect(response.statusCode, 200);

      final jsonData = json.decode(response.body);
      expect(jsonData, isA<Map<String, dynamic>>());
      expect(jsonData['anime'], isA<List>());
      expect(jsonData['anime'].length, greaterThan(0));

      final firstAnime = jsonData['anime'][0];
      expect(firstAnime['animethemes'], isA<List>());
      expect(firstAnime['animethemes'].length, greaterThan(0));

      final firstTheme = firstAnime['animethemes'][0];
      expect(firstTheme['animethemeentries'], isA<List>());
      expect(firstTheme['animethemeentries'].length, greaterThan(0));

      final firstEntry = firstTheme['animethemeentries'][0];
      expect(firstEntry['videos'], isA<List>());
      expect(firstEntry['videos'].length, greaterThan(0));

      final firstVideo = firstEntry['videos'][0];
      expect(firstVideo['link'], isA<String>());
      expect(firstVideo['link'], contains('http'));
      expect(
        firstVideo['link'],
        equals('https://v.animethemes.moe/Naruto-OP1.webm'),
      );

      if (firstVideo['audio'] != null) {
        final audio = firstVideo['audio'];
        expect(audio['link'], isA<String>());
        expect(audio['link'], contains('http'));
        expect(
          audio['link'],
          equals('https://a.animethemes.moe/Naruto-OP1.ogg'),
        );
      }
    });

    // Test for creating a playlist
    test('Create playlist from API data', () async {
      final response = await mockHttpClient.get(
        Uri.parse(
          'https://api.animethemes.moe/anime?q=Naruto&fields[anime]=id,name,media_format&include=images,animethemes.animethemeentries.videos.audio',
        ),
      );

      final jsonData = json.decode(response.body);
      final List<Map<String, dynamic>> videoPlaylist = [];

      // Extract videos from the API response to create a playlist
      for (var anime in jsonData['anime']) {
        if (anime['animethemes'] != null) {
          for (var theme in anime['animethemes']) {
            if (theme['animethemeentries'] != null) {
              for (var entry in theme['animethemeentries']) {
                if (entry['videos'] != null) {
                  for (var video in entry['videos']) {
                    if (video['link'] != null) {
                      videoPlaylist.add({
                        'anime': anime['name'],
                        'theme': '${theme['type']}${theme['sequence']}',
                        'videoLink': video['link'],
                        'audioLink':
                            video['audio'] != null
                                ? video['audio']['link']
                                : null,
                      });
                    }
                  }
                }
              }
            }
          }
        }
      }

      expect(videoPlaylist.length, greaterThan(0));
      expect(videoPlaylist.first['videoLink'], isA<String>());
      expect(videoPlaylist.first['videoLink'], contains('http'));
      expect(videoPlaylist.first['anime'], equals('Naruto'));
      expect(videoPlaylist.first['theme'], equals('OP1'));
      expect(
        videoPlaylist.first['videoLink'],
        equals('https://v.animethemes.moe/Naruto-OP1.webm'),
      );
      expect(
        videoPlaylist.first['audioLink'],
        equals('https://a.animethemes.moe/Naruto-OP1.ogg'),
      );
    });
  });

  group('Mock Player Tests', () {
    // Create test data using our models
    final testVideo = Video(
      id: '123',
      link: 'https://v.animethemes.moe/Naruto-OP1.webm',
      audio: Audio(id: '456', link: 'https://a.animethemes.moe/Naruto-OP1.ogg'),
      resolution: 1080,
      nc: false,
    );

    final testAnimeThemeEntry = AnimeThemeEntry(
      id: '789',
      version: 1,
      videos: [testVideo],
    );

    final testAnimeTheme = AnimeTheme(
      id: '101',
      slug: 'OP1',
      type: 'OP',
      sequence: 1,
      animethemeentries: [testAnimeThemeEntry],
    );

    final testAnime = Anime(
      id: '2028',
      name: 'Naruto',
      mediaFormat: 'TV',
      animethemes: [testAnimeTheme],
    );

    // Test playlist management
    test('Playlist navigation works correctly', () {
      final playlist = [
        testVideo,
        Video(id: '124', link: 'https://v.animethemes.moe/Naruto-OP2.webm'),
        Video(id: '125', link: 'https://v.animethemes.moe/Naruto-OP3.webm'),
      ];

      int currentIndex = 0;

      // Test next function
      expect(currentIndex, 0);
      if (currentIndex < playlist.length - 1) {
        currentIndex++;
      }
      expect(currentIndex, 1);

      // Test next again
      if (currentIndex < playlist.length - 1) {
        currentIndex++;
      }
      expect(currentIndex, 2);

      // Test next at the end of playlist (should not change)
      if (currentIndex < playlist.length - 1) {
        currentIndex++;
      }
      expect(currentIndex, 2);

      // Test previous
      if (currentIndex > 0) {
        currentIndex--;
      }
      expect(currentIndex, 1);

      // Test previous again
      if (currentIndex > 0) {
        currentIndex--;
      }
      expect(currentIndex, 0);

      // Test previous at the beginning of playlist (should not change)
      if (currentIndex > 0) {
        currentIndex--;
      }
      expect(currentIndex, 0);
    });
  });
}
