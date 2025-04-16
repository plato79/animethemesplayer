import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime.dart';
import '../models/video.dart';
import '../models/audio.dart';
import '../services/anime_api_service.dart';

// API service provider
final animeApiServiceProvider = Provider<AnimeApiService>((ref) {
  return AnimeApiService();
});

// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Search results provider
final searchResultsProvider = FutureProvider<List<Anime>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) {
    return [];
  }
  final apiService = ref.watch(animeApiServiceProvider);
  final response = await apiService.searchAnime(query);
  return response.anime;
});

// Selected video provider
final selectedMediaProvider = StateProvider<Video?>((ref) => null);

// Selected audio provider
final selectedAudioProvider = StateProvider<Audio?>((ref) => null);

// Playback status provider
final isPlayingProvider = StateProvider<bool>((ref) => false);

// Current position provider (for audio/video)
final currentPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

// Total duration provider (for audio/video)
final totalDurationProvider = StateProvider<Duration>((ref) => Duration.zero);

// Current anime provider
final currentAnimeProvider = StateProvider<Anime?>((ref) => null);

// Current anime image provider
final currentAnimeImageProvider = StateProvider<String?>((ref) => null);

// Playback mode enum
enum PlaybackMode {
  single, // Play a single item
  playlist, // Play from playlist
}

// Playback mode provider
final playbackModeProvider = StateProvider<PlaybackMode>(
  (ref) => PlaybackMode.single,
);

// Provider for anime list
final animeProvider = FutureProvider<List<Anime>>((ref) async {
  final apiService = ref.watch(animeApiServiceProvider);
  return await apiService.fetchAnimeList();
});

// Provider for selected anime
final selectedAnimeProvider = StateProvider<Anime?>((ref) => null);

// Provider for anime details
final animeDetailsProvider = FutureProvider.family<Anime, String>((
  ref,
  animeSlug,
) async {
  final apiService = ref.watch(animeApiServiceProvider);
  return await apiService.fetchAnimeDetailsBySlug(animeSlug);
});

// Provider for audio list by anime
final animeAudioProvider = FutureProvider.family<List<Audio>, String>((
  ref,
  animeSlug,
) async {
  final apiService = ref.watch(animeApiServiceProvider);
  return await apiService.fetchAnimeAudio(animeSlug);
});

// Provider for video list by anime
final animeVideoProvider = FutureProvider.family<List<Video>, String>((
  ref,
  animeSlug,
) async {
  final apiService = ref.watch(animeApiServiceProvider);
  return await apiService.fetchAnimeVideo(animeSlug);
});

// Format duration utility function
String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));

  if (duration.inHours > 0) {
    return '$hours:$minutes:$seconds';
  } else {
    return '$minutes:$seconds';
  }
}
