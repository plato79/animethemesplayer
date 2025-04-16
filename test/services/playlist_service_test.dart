import 'package:anime_themes_media_player/models/audio.dart';
import 'package:anime_themes_media_player/models/video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlaylistItem {
  final String title;
  final String animeName;
  final String themeType;
  final Video video;

  PlaylistItem({
    required this.title,
    required this.animeName,
    required this.themeType,
    required this.video,
  });
}

class PlaylistService {
  List<PlaylistItem> _playlist = [];
  int _currentIndex = 0;

  List<PlaylistItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  PlaylistItem? get currentItem =>
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;

  void addItem(PlaylistItem item) {
    _playlist.add(item);
  }

  void addItems(List<PlaylistItem> items) {
    _playlist.addAll(items);
  }

  void removeItem(int index) {
    if (index >= 0 && index < _playlist.length) {
      _playlist.removeAt(index);
      if (_currentIndex >= _playlist.length) {
        _currentIndex = _playlist.isEmpty ? 0 : _playlist.length - 1;
      }
    }
  }

  void clearPlaylist() {
    _playlist.clear();
    _currentIndex = 0;
  }

  bool next() {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      return true;
    }
    return false;
  }

  bool previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      return true;
    }
    return false;
  }

  bool jumpToIndex(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      return true;
    }
    return false;
  }
}

void main() {
  group('PlaylistService Tests', () {
    late PlaylistService playlistService;

    setUp(() {
      playlistService = PlaylistService();
    });

    test('Add items to playlist', () {
      // Create test items
      final item1 = PlaylistItem(
        title: 'Naruto OP1',
        animeName: 'Naruto',
        themeType: 'OP1',
        video: Video(
          id: '1',
          link: 'https://v.animethemes.moe/Naruto-OP1.webm',
          audio: Audio(
            id: '1',
            link: 'https://a.animethemes.moe/Naruto-OP1.ogg',
          ),
        ),
      );

      final item2 = PlaylistItem(
        title: 'Naruto OP2',
        animeName: 'Naruto',
        themeType: 'OP2',
        video: Video(
          id: '2',
          link: 'https://v.animethemes.moe/Naruto-OP2.webm',
          audio: Audio(
            id: '2',
            link: 'https://a.animethemes.moe/Naruto-OP2.ogg',
          ),
        ),
      );

      // Add items
      playlistService.addItem(item1);
      expect(playlistService.playlist.length, 1);
      expect(playlistService.currentItem, item1);

      playlistService.addItem(item2);
      expect(playlistService.playlist.length, 2);
      // Current item should still be the first one
      expect(playlistService.currentItem, item1);
    });

    test('Navigate through playlist', () {
      // Create and add test items
      final items = List.generate(
        5,
        (i) => PlaylistItem(
          title: 'Naruto OP${i + 1}',
          animeName: 'Naruto',
          themeType: 'OP${i + 1}',
          video: Video(
            id: '${i + 1}',
            link: 'https://v.animethemes.moe/Naruto-OP${i + 1}.webm',
            audio: Audio(
              id: '${i + 1}',
              link: 'https://a.animethemes.moe/Naruto-OP${i + 1}.ogg',
            ),
          ),
        ),
      );

      playlistService.addItems(items);
      expect(playlistService.playlist.length, 5);

      // Test initial state
      expect(playlistService.currentIndex, 0);
      expect(playlistService.currentItem, items[0]);

      // Test next
      expect(playlistService.next(), isTrue);
      expect(playlistService.currentIndex, 1);
      expect(playlistService.currentItem, items[1]);

      // Test jump to index
      expect(playlistService.jumpToIndex(3), isTrue);
      expect(playlistService.currentIndex, 3);
      expect(playlistService.currentItem, items[3]);

      // Test previous
      expect(playlistService.previous(), isTrue);
      expect(playlistService.currentIndex, 2);
      expect(playlistService.currentItem, items[2]);

      // Test bounds
      // Go to first item
      expect(playlistService.jumpToIndex(0), isTrue);
      // Try to go before first item
      expect(playlistService.previous(), isFalse);
      expect(playlistService.currentIndex, 0);

      // Go to last item
      expect(playlistService.jumpToIndex(4), isTrue);
      // Try to go after last item
      expect(playlistService.next(), isFalse);
      expect(playlistService.currentIndex, 4);

      // Test invalid jump
      expect(playlistService.jumpToIndex(10), isFalse);
      expect(playlistService.currentIndex, 4);
    });

    test('Remove items from playlist', () {
      // Create and add test items
      final items = List.generate(
        5,
        (i) => PlaylistItem(
          title: 'Naruto OP${i + 1}',
          animeName: 'Naruto',
          themeType: 'OP${i + 1}',
          video: Video(
            id: '${i + 1}',
            link: 'https://v.animethemes.moe/Naruto-OP${i + 1}.webm',
            audio: Audio(
              id: '${i + 1}',
              link: 'https://a.animethemes.moe/Naruto-OP${i + 1}.ogg',
            ),
          ),
        ),
      );

      playlistService.addItems(items);

      // Remove current item (first item)
      playlistService.removeItem(0);
      expect(playlistService.playlist.length, 4);
      expect(playlistService.currentIndex, 0);
      expect(playlistService.currentItem, items[1]);

      // Jump to last item
      playlistService.jumpToIndex(3);
      expect(playlistService.currentItem, items[4]);

      // Remove last item
      playlistService.removeItem(3);
      expect(playlistService.playlist.length, 3);
      expect(playlistService.currentIndex, 2);
      expect(playlistService.currentItem, items[3]);

      // Clear playlist
      playlistService.clearPlaylist();
      expect(playlistService.playlist, isEmpty);
      expect(playlistService.currentIndex, 0);
      expect(playlistService.currentItem, isNull);
    });
  });

  group('Playlist with API Data Tests', () {
    test('Create playlist from API data', () async {
      // Fetch real data from API
      final response = await http.get(
        Uri.parse(
          'https://api.animethemes.moe/anime?q=Naruto&fields[anime]=id,name,media_format&include=images,animethemes.animethemeentries.videos.audio',
        ),
      );

      expect(response.statusCode, 200);

      final jsonData = json.decode(response.body);
      expect(jsonData['anime'], isA<List>());

      // Create playlist service
      final playlistService = PlaylistService();

      // Extract data from API response to create playlist items
      for (var anime in jsonData['anime']) {
        if (anime['animethemes'] != null) {
          for (var theme in anime['animethemes']) {
            if (theme['animethemeentries'] != null) {
              for (var entry in theme['animethemeentries']) {
                if (entry['videos'] != null) {
                  for (var videoJson in entry['videos']) {
                    if (videoJson['link'] != null) {
                      // Create audio if available
                      Audio? audio;
                      if (videoJson['audio'] != null) {
                        audio = Audio(
                          id: videoJson['audio']['id'].toString(),
                          link: videoJson['audio']['link'],
                          basename: videoJson['audio']['basename'],
                          filename: videoJson['audio']['filename'],
                        );
                      }

                      // Create video
                      final video = Video(
                        id: videoJson['id'].toString(),
                        link: videoJson['link'],
                        audio: audio,
                        basename: videoJson['basename'],
                        filename: videoJson['filename'],
                        resolution: videoJson['resolution'],
                      );

                      // Create playlist item
                      final themeType = theme['type'] ?? '';
                      final sequence =
                          theme['sequence'] != null
                              ? theme['sequence'].toString()
                              : '';
                      final themeInfo = '$themeType$sequence';

                      final playlistItem = PlaylistItem(
                        title: '${anime['name']} - $themeInfo',
                        animeName: anime['name'],
                        themeType: themeInfo,
                        video: video,
                      );

                      // Add to playlist
                      playlistService.addItem(playlistItem);
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Verify playlist was populated with items
      expect(playlistService.playlist.length, greaterThan(0));
      expect(playlistService.currentItem, isNotNull);

      // Test playing through playlist
      int initialCount = 0;
      while (playlistService.next()) {
        initialCount++;
        expect(playlistService.currentItem, isNotNull);

        // Test that all items have the required properties
        final currentItem = playlistService.currentItem!;
        expect(currentItem.title, isNotEmpty);
        expect(currentItem.animeName, isNotEmpty);
        expect(currentItem.themeType, isNotEmpty);
        expect(currentItem.video, isNotNull);
        expect(currentItem.video.link, contains('http'));

        // Check audio when available
        if (currentItem.video.audio != null) {
          expect(currentItem.video.audio!.link, contains('http'));
        }
      }

      // Verify we could navigate through the playlist
      expect(initialCount, greaterThan(0));
      expect(
        playlistService.currentIndex,
        equals(playlistService.playlist.length - 1),
      );

      // Test going backwards through the playlist
      int backCount = 0;
      while (playlistService.previous()) {
        backCount++;
      }

      // Verify we went all the way back
      expect(backCount, equals(playlistService.playlist.length - 1));
      expect(playlistService.currentIndex, 0);
    });
  });
}
