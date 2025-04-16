import 'package:anime_themes_media_player/models/audio.dart';
import 'package:anime_themes_media_player/models/video.dart';
import 'package:anime_themes_media_player/providers/playlist_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioPlaylistNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is empty', () {
      expect(container.read(audioPlaylistProvider), isEmpty);
    });

    test('Add audio to playlist', () {
      final audio = Audio(
        id: 'test-id',
        link: 'https://example.com/audio.ogg',
        basename: 'Test Audio',
      );

      container.read(audioPlaylistProvider.notifier).addAudio(audio);

      expect(container.read(audioPlaylistProvider), [audio]);
      expect(container.read(audioPlaylistProvider).length, 1);
    });

    test('Adding duplicate audio does not create duplicates', () {
      final audio = Audio(
        id: 'test-id',
        link: 'https://example.com/audio.ogg',
        basename: 'Test Audio',
      );

      container.read(audioPlaylistProvider.notifier).addAudio(audio);
      container
          .read(audioPlaylistProvider.notifier)
          .addAudio(audio); // Add same audio again

      expect(container.read(audioPlaylistProvider).length, 1);
    });

    test('Add multiple audio items', () {
      final audio1 = Audio(
        id: 'test-id-1',
        link: 'https://example.com/audio1.ogg',
        basename: 'Test Audio 1',
      );

      final audio2 = Audio(
        id: 'test-id-2',
        link: 'https://example.com/audio2.ogg',
        basename: 'Test Audio 2',
      );

      container.read(audioPlaylistProvider.notifier).addAudioList([
        audio1,
        audio2,
      ]);

      expect(container.read(audioPlaylistProvider).length, 2);
    });

    test('Remove audio from playlist', () {
      final audio1 = Audio(
        id: 'test-id-1',
        link: 'https://example.com/audio1.ogg',
        basename: 'Test Audio 1',
      );

      final audio2 = Audio(
        id: 'test-id-2',
        link: 'https://example.com/audio2.ogg',
        basename: 'Test Audio 2',
      );

      container.read(audioPlaylistProvider.notifier).addAudioList([
        audio1,
        audio2,
      ]);
      container.read(audioPlaylistProvider.notifier).removeAudio('test-id-1');

      expect(container.read(audioPlaylistProvider).length, 1);
      expect(container.read(audioPlaylistProvider).first.id, 'test-id-2');
    });

    test('Clear playlist', () {
      final audio1 = Audio(
        id: 'test-id-1',
        link: 'https://example.com/audio1.ogg',
        basename: 'Test Audio 1',
      );

      final audio2 = Audio(
        id: 'test-id-2',
        link: 'https://example.com/audio2.ogg',
        basename: 'Test Audio 2',
      );

      container.read(audioPlaylistProvider.notifier).addAudioList([
        audio1,
        audio2,
      ]);
      container.read(audioPlaylistProvider.notifier).clearPlaylist();

      expect(container.read(audioPlaylistProvider), isEmpty);
    });

    test('Play next in playlist', () {
      final audio1 = Audio(
        id: 'test-id-1',
        link: 'https://example.com/audio1.ogg',
        basename: 'Test Audio 1',
      );

      final audio2 = Audio(
        id: 'test-id-2',
        link: 'https://example.com/audio2.ogg',
        basename: 'Test Audio 2',
      );

      container.read(audioPlaylistProvider.notifier).addAudioList([
        audio1,
        audio2,
      ]);

      final nextAudio =
          container.read(audioPlaylistProvider.notifier).playNext();
      expect(nextAudio?.id, 'test-id-2');
    });

    test('Play previous in playlist', () {
      final audio1 = Audio(
        id: 'test-id-1',
        link: 'https://example.com/audio1.ogg',
        basename: 'Test Audio 1',
      );

      final audio2 = Audio(
        id: 'test-id-2',
        link: 'https://example.com/audio2.ogg',
        basename: 'Test Audio 2',
      );

      container.read(audioPlaylistProvider.notifier).addAudioList([
        audio1,
        audio2,
      ]);
      container
          .read(audioPlaylistProvider.notifier)
          .playNext(); // Move to second item

      final prevAudio =
          container.read(audioPlaylistProvider.notifier).playPrevious();
      expect(prevAudio?.id, 'test-id-1');
    });
  });

  group('VideoPlaylistNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is empty', () {
      expect(container.read(videoPlaylistProvider), isEmpty);
    });

    test('Add video to playlist', () {
      final video = Video(
        id: 'test-id',
        link: 'https://example.com/video.webm',
        resolution: 720,
        basename: 'Test Video',
      );

      container.read(videoPlaylistProvider.notifier).addVideo(video);

      expect(container.read(videoPlaylistProvider), [video]);
      expect(container.read(videoPlaylistProvider).length, 1);
    });

    test('Adding duplicate video does not create duplicates', () {
      final video = Video(
        id: 'test-id',
        link: 'https://example.com/video.webm',
        resolution: 720,
        basename: 'Test Video',
      );

      container.read(videoPlaylistProvider.notifier).addVideo(video);
      container
          .read(videoPlaylistProvider.notifier)
          .addVideo(video); // Add same video again

      expect(container.read(videoPlaylistProvider).length, 1);
    });

    test('Add multiple video items', () {
      final video1 = Video(
        id: 'test-id-1',
        link: 'https://example.com/video1.webm',
        resolution: 720,
        basename: 'Test Video 1',
      );

      final video2 = Video(
        id: 'test-id-2',
        link: 'https://example.com/video2.webm',
        resolution: 1080,
        basename: 'Test Video 2',
      );

      container.read(videoPlaylistProvider.notifier).addVideoList([
        video1,
        video2,
      ]);

      expect(container.read(videoPlaylistProvider).length, 2);
    });

    test('Remove video from playlist', () {
      final video1 = Video(
        id: 'test-id-1',
        link: 'https://example.com/video1.webm',
        resolution: 720,
        basename: 'Test Video 1',
      );

      final video2 = Video(
        id: 'test-id-2',
        link: 'https://example.com/video2.webm',
        resolution: 1080,
        basename: 'Test Video 2',
      );

      container.read(videoPlaylistProvider.notifier).addVideoList([
        video1,
        video2,
      ]);
      container.read(videoPlaylistProvider.notifier).removeVideo('test-id-1');

      expect(container.read(videoPlaylistProvider).length, 1);
      expect(container.read(videoPlaylistProvider).first.id, 'test-id-2');
    });

    test('Clear playlist', () {
      final video1 = Video(
        id: 'test-id-1',
        link: 'https://example.com/video1.webm',
        resolution: 720,
        basename: 'Test Video 1',
      );

      final video2 = Video(
        id: 'test-id-2',
        link: 'https://example.com/video2.webm',
        resolution: 1080,
        basename: 'Test Video 2',
      );

      container.read(videoPlaylistProvider.notifier).addVideoList([
        video1,
        video2,
      ]);
      container.read(videoPlaylistProvider.notifier).clearPlaylist();

      expect(container.read(videoPlaylistProvider), isEmpty);
    });

    test('Play next in playlist', () {
      final video1 = Video(
        id: 'test-id-1',
        link: 'https://example.com/video1.webm',
        resolution: 720,
        basename: 'Test Video 1',
      );

      final video2 = Video(
        id: 'test-id-2',
        link: 'https://example.com/video2.webm',
        resolution: 1080,
        basename: 'Test Video 2',
      );

      container.read(videoPlaylistProvider.notifier).addVideoList([
        video1,
        video2,
      ]);

      final nextVideo =
          container.read(videoPlaylistProvider.notifier).playNext();
      expect(nextVideo?.id, 'test-id-2');
    });

    test('Play previous in playlist', () {
      final video1 = Video(
        id: 'test-id-1',
        link: 'https://example.com/video1.webm',
        resolution: 720,
        basename: 'Test Video 1',
      );

      final video2 = Video(
        id: 'test-id-2',
        link: 'https://example.com/video2.webm',
        resolution: 1080,
        basename: 'Test Video 2',
      );

      container.read(videoPlaylistProvider.notifier).addVideoList([
        video1,
        video2,
      ]);
      container
          .read(videoPlaylistProvider.notifier)
          .playNext(); // Move to second item

      final prevVideo =
          container.read(videoPlaylistProvider.notifier).playPrevious();
      expect(prevVideo?.id, 'test-id-1');
    });

    test('Toggle shuffle mode', () {
      final videos = List.generate(
        5,
        (index) => Video(
          id: 'test-id-$index',
          link: 'https://example.com/video$index.webm',
          resolution: 720,
          basename: 'Test Video $index',
        ),
      );

      container.read(videoPlaylistProvider.notifier).addVideoList(videos);

      // Enable shuffle mode
      container.read(videoPlaylistProvider.notifier).toggleShuffle();

      // Can't directly test the internal shuffled indices, but we can test that
      // a complete playlist cycle visits all videos exactly once
      final visitedIds = <String>{};

      // Play through the entire playlist and collect ids
      for (var i = 0; i < videos.length; i++) {
        final video =
            container.read(videoPlaylistProvider.notifier).getCurrentVideo();
        visitedIds.add(video!.id);
        container.read(videoPlaylistProvider.notifier).playNext();
      }

      // We should have visited each video exactly once
      expect(visitedIds.length, videos.length);
    });
  });
}
