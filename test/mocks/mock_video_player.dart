import 'dart:async';
import 'dart:ui';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {
  final VideoPlayerValue _value = VideoPlayerValue(
    duration: const Duration(seconds: 60),
    size: const Size(640, 480),
    position: const Duration(seconds: 0),
    isPlaying: false,
    isLooping: false,
    isBuffering: false,
    volume: 1.0,
    errorDescription: null,
    playbackSpeed: 1.0,
  );

  @override
  VideoPlayerValue get value => _value;

  @override
  Future<void> initialize() async => Future.value();

  @override
  Future<void> play() async => Future.value();

  @override
  Future<void> pause() async => Future.value();

  @override
  Future<void> seekTo(Duration position) async => Future.value();

  @override
  Future<void> setVolume(double volume) async => Future.value();

  @override
  Future<void> setPlaybackSpeed(double speed) async => Future.value();

  @override
  Future<void> dispose() async => Future.value();
}
