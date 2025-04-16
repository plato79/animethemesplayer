import 'package:anime_themes_media_player/models/anime_response.dart';
import 'package:anime_themes_media_player/services/anime_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  group('AnimeApiService Tests', () {
    late MockHttpClient mockHttpClient;
    late AnimeApiService apiService;

    setUpAll(() {
      registerFallbackValue(FakeUri());
    });

    setUp(() {
      mockHttpClient = MockHttpClient();
      apiService = AnimeApiService(client: mockHttpClient);
    });

    test('searchAnime returns AnimeResponse on successful API call', () async {
      // Arrange
      const query = 'Naruto';
      final uri = Uri.parse(
        'https://api.animethemes.moe/anime?q=$query&fields[anime]=id,name,media_format&include=images,animethemes.animethemeentries.videos.audio',
      );

      // Read a real API response from the file to simulate real data
      final realApiResponse = await http.get(uri);
      final responseJson = realApiResponse.body;

      // Configure mock to return the real API response
      when(
        () => mockHttpClient.get(any()),
      ).thenAnswer((_) async => http.Response(responseJson, 200));

      // Act
      final result = await apiService.searchAnime(query);

      // Assert
      verify(() => mockHttpClient.get(any())).called(1);
      expect(result, isA<AnimeResponse>());
      expect(result.anime, isNotEmpty);

      // Check for each anime if it has proper structure
      for (final anime in result.anime) {
        expect(anime.id, isNotEmpty);
        expect(anime.name, isNotEmpty);
        expect(anime.mediaFormat, isNotEmpty);

        // Check for themes (at least for the ones that have themes)
        if (anime.animethemes != null && anime.animethemes!.isNotEmpty) {
          for (final theme in anime.animethemes!) {
            expect(theme.id, isNotEmpty);
            expect(theme.slug, isNotEmpty);

            // Check for entries
            if (theme.animethemeentries != null &&
                theme.animethemeentries!.isNotEmpty) {
              for (final entry in theme.animethemeentries!) {
                expect(entry.id, isNotEmpty);

                // Check for videos
                if (entry.videos != null && entry.videos!.isNotEmpty) {
                  for (final video in entry.videos!) {
                    expect(video.id, isNotEmpty);
                    expect(video.link, isNotEmpty);
                    expect(video.link, contains('http'));

                    // Check for audio if available
                    if (video.audio != null) {
                      expect(video.audio!.id, isNotEmpty);
                      expect(video.audio!.link, isNotEmpty);
                      expect(video.audio!.link, contains('http'));
                    }
                  }
                }
              }
            }
          }
        }

        // Check for images
        if (anime.images != null && anime.images!.isNotEmpty) {
          for (final image in anime.images!) {
            expect(image.id, isNotEmpty);
            expect(image.link, isNotEmpty);
            expect(image.link, contains('http'));
          }
        }
      }
    });

    test('searchAnime handles API error properly', () async {
      // Arrange
      const query = 'Naruto';

      // Configure mock to return a server error
      when(() => mockHttpClient.get(any())).thenAnswer(
        (_) async => http.Response('{"error": "Internal Server Error"}', 500),
      );

      // Act & Assert
      expect(() => apiService.searchAnime(query), throwsException);
      verify(() => mockHttpClient.get(any())).called(1);
    });

    test('searchAnime handles empty response properly', () async {
      // Arrange
      const query = 'NonExistentAnime12345';

      // Configure mock to return an empty anime list
      when(
        () => mockHttpClient.get(any()),
      ).thenAnswer((_) async => http.Response('{"anime": []}', 200));

      // Act
      final result = await apiService.searchAnime(query);

      // Assert
      verify(() => mockHttpClient.get(any())).called(1);
      expect(result, isA<AnimeResponse>());
      expect(result.anime, isEmpty);
    });
  });

  group('Live API Tests', () {
    test(
      'Real API call returns valid data',
      () async {
        final client = http.Client();
        final apiService = AnimeApiService(client: client);

        // Make a real API call
        final result = await apiService.searchAnime('Naruto');

        // Verify the response
        expect(result, isA<AnimeResponse>());
        expect(result.anime, isNotEmpty);

        // Check the first anime
        final firstAnime = result.anime.first;
        expect(firstAnime.id, isNotEmpty);
        expect(firstAnime.name, isNotEmpty);
        expect(firstAnime.mediaFormat, isNotEmpty);

        // Clean up the client
        client.close();
      },
      timeout: Timeout(Duration(minutes: 2)),
    ); // Increase timeout for network operations
  });
}
