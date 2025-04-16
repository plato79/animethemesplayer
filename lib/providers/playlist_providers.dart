import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio.dart';
import '../models/video.dart';

// Provider to control shuffle state across playlists
final isShuffledProvider = StateProvider<bool>((ref) => false);

// Provider for the current audio being played in the audio player screen
final currentPlayingAudioProvider = StateProvider<Audio?>((ref) => null);

// Provider for audio playlist
final audioPlaylistProvider =
    StateNotifierProvider<AudioPlaylistNotifier, List<Audio>>(
      (ref) => AudioPlaylistNotifier(),
    );

// Provider for the current position in the playlist
final currentPlaylistIndexProvider = StateProvider<int>((ref) => 0);

class AudioPlaylistNotifier extends StateNotifier<List<Audio>> {
  AudioPlaylistNotifier() : super([]);

  // The current index in the playlist
  int _currentIndex = 0;

  // Track if we're in shuffle mode
  bool _isShuffled = false;
  List<int> _shuffledIndices = [];

  // Add audio to playlist if not already in it
  void addAudio(Audio audio) {
    if (!state.any((element) => element.id == audio.id)) {
      state = [...state, audio];
    }
  }

  // Add multiple audio items
  void addAudioList(List<Audio> audioList) {
    // Filter existing items
    final newItems =
        audioList
            .where(
              (newAudio) =>
                  !state.any((existing) => existing.id == newAudio.id),
            )
            .toList();

    if (newItems.isNotEmpty) {
      state = [...state, ...newItems];

      // If in shuffle mode, update the shuffled indices
      if (_isShuffled) {
        _updateShuffledIndices();
      }
    }
  }

  // Add all audio items (alias for addAudioList for backward compatibility)
  void addAll(List<Audio> audioList) {
    addAudioList(audioList);
  }

  // Set current audio and update index
  void setCurrentAudio(Audio audio) {
    final index = state.indexWhere((item) => item.id == audio.id);
    if (index != -1) {
      _currentIndex = index;
    } else {
      // If not in playlist, add it and set as current
      addAudio(audio);
      _currentIndex = state.length - 1;
    }
  }

  // Remove audio from playlist
  void removeAudio(String audioId) {
    state = state.where((audio) => audio.id != audioId).toList();

    // Update current index if necessary
    if (_currentIndex >= state.length) {
      _currentIndex = state.isEmpty ? 0 : state.length - 1;
    }

    // Update shuffled indices if in shuffle mode
    if (_isShuffled) {
      _updateShuffledIndices();
    }
  }

  // Clear the entire playlist
  void clearPlaylist() {
    state = [];
    _currentIndex = 0;
    _shuffledIndices = [];
  }

  // Update shuffled indices
  void _updateShuffledIndices() {
    // Create indices list and shuffle it
    final indices = List.generate(state.length, (index) => index);

    // Preserve the current index if possible
    final currentAudioId =
        _currentIndex < state.length ? state[_currentIndex].id : null;

    // Shuffle the indices
    indices.shuffle();
    _shuffledIndices = indices;

    // Find the current audio in the shuffled list to maintain position
    if (currentAudioId != null) {
      final currentAudio = state.firstWhere(
        (audio) => audio.id == currentAudioId,
      );
      final currentIndexInOriginal = state.indexOf(currentAudio);
      final currentIndexInShuffled = _shuffledIndices.indexOf(
        currentIndexInOriginal,
      );

      // If found, make it the current index in shuffled indices
      if (currentIndexInShuffled != -1) {
        final temp = _shuffledIndices[0];
        _shuffledIndices[0] = _shuffledIndices[currentIndexInShuffled];
        _shuffledIndices[currentIndexInShuffled] = temp;
      }
    }
  }

  // Toggle shuffle mode
  void toggleShuffle() {
    if (_isShuffled) {
      // Turn off shuffle
      _isShuffled = false;
    } else {
      // Turn on shuffle
      _isShuffled = true;
      _updateShuffledIndices();
    }
  }

  // Get the current audio
  Audio? getCurrentAudio() {
    if (state.isEmpty) return null;
    return _currentIndex < state.length ? state[_currentIndex] : null;
  }

  // Play a specific audio by ID
  Audio? playById(String audioId) {
    final index = state.indexWhere((audio) => audio.id == audioId);
    if (index != -1) {
      _currentIndex = index;
      return state[_currentIndex];
    }
    return null;
  }

  // Play next audio in playlist
  Audio? playNext() {
    if (state.isEmpty) return null;

    if (_isShuffled) {
      final currentShuffledIndex = _shuffledIndices.indexOf(_currentIndex);
      final nextShuffledIndex =
          (currentShuffledIndex + 1) % _shuffledIndices.length;
      _currentIndex = _shuffledIndices[nextShuffledIndex];
    } else {
      _currentIndex = (_currentIndex + 1) % state.length;
    }

    return state[_currentIndex];
  }

  // Play previous audio in playlist
  Audio? playPrevious() {
    if (state.isEmpty) return null;

    if (_isShuffled) {
      final currentShuffledIndex = _shuffledIndices.indexOf(_currentIndex);
      final prevShuffledIndex =
          (currentShuffledIndex - 1 + _shuffledIndices.length) %
          _shuffledIndices.length;
      _currentIndex = _shuffledIndices[prevShuffledIndex];
    } else {
      _currentIndex = (_currentIndex - 1 + state.length) % state.length;
    }

    return state[_currentIndex];
  }

  // Get current index
  int getCurrentIndex() {
    return _currentIndex;
  }

  // Set current index
  void setCurrentIndex(int index) {
    if (index >= 0 && index < state.length) {
      _currentIndex = index;
    }
  }
}

// Provider for video playlist
final videoPlaylistProvider =
    StateNotifierProvider<VideoPlaylistNotifier, List<Video>>(
      (ref) => VideoPlaylistNotifier(),
    );

class VideoPlaylistNotifier extends StateNotifier<List<Video>> {
  VideoPlaylistNotifier() : super([]);

  // The current index in the playlist
  int _currentIndex = 0;

  // Track if we're in shuffle mode
  bool _isShuffled = false;
  List<int> _shuffledIndices = [];

  // Add video to playlist if not already in it
  void addVideo(Video video) {
    if (!state.any((element) => element.id == video.id)) {
      state = [...state, video];
    }
  }

  // Add multiple video items
  void addVideoList(List<Video> videoList) {
    // Filter existing items
    final newItems =
        videoList
            .where(
              (newVideo) =>
                  !state.any((existing) => existing.id == newVideo.id),
            )
            .toList();

    if (newItems.isNotEmpty) {
      state = [...state, ...newItems];

      // If in shuffle mode, update the shuffled indices
      if (_isShuffled) {
        _updateShuffledIndices();
      }
    }
  }

  // Add all videos (alias for addVideoList for backward compatibility)
  void addAll(List<Video> videoList) {
    addVideoList(videoList);
  }

  // Remove from playlist (alias for removeVideo for backward compatibility)
  void removeFromPlaylist(String videoId) {
    removeVideo(videoId);
  }

  // Remove video from playlist
  void removeVideo(String videoId) {
    state = state.where((video) => video.id != videoId).toList();

    // Update current index if necessary
    if (_currentIndex >= state.length) {
      _currentIndex = state.isEmpty ? 0 : state.length - 1;
    }

    // Update shuffled indices if in shuffle mode
    if (_isShuffled) {
      _updateShuffledIndices();
    }
  }

  // Clear the entire playlist
  void clearPlaylist() {
    state = [];
    _currentIndex = 0;
    _shuffledIndices = [];
  }

  // Update shuffled indices
  void _updateShuffledIndices() {
    // Create indices list and shuffle it
    final indices = List.generate(state.length, (index) => index);

    // Preserve the current index if possible
    final currentVideoId =
        _currentIndex < state.length ? state[_currentIndex].id : null;

    // Shuffle the indices
    indices.shuffle();
    _shuffledIndices = indices;

    // Find the current video in the shuffled list to maintain position
    if (currentVideoId != null) {
      final currentVideo = state.firstWhere(
        (video) => video.id == currentVideoId,
      );
      final currentIndexInOriginal = state.indexOf(currentVideo);
      final currentIndexInShuffled = _shuffledIndices.indexOf(
        currentIndexInOriginal,
      );

      // If found, make it the current index in shuffled indices
      if (currentIndexInShuffled != -1) {
        final temp = _shuffledIndices[0];
        _shuffledIndices[0] = _shuffledIndices[currentIndexInShuffled];
        _shuffledIndices[currentIndexInShuffled] = temp;
      }
    }
  }

  // Toggle shuffle mode
  void toggleShuffle() {
    if (_isShuffled) {
      // Turn off shuffle
      _isShuffled = false;
    } else {
      // Turn on shuffle
      _isShuffled = true;
      _updateShuffledIndices();
    }
  }

  // Get the current video
  Video? getCurrentVideo() {
    if (state.isEmpty) return null;
    return _currentIndex < state.length ? state[_currentIndex] : null;
  }

  // Play a specific video by ID
  Video? playById(String videoId) {
    final index = state.indexWhere((video) => video.id == videoId);
    if (index != -1) {
      _currentIndex = index;
      return state[_currentIndex];
    }
    return null;
  }

  // Play next video in playlist
  Video? playNext() {
    if (state.isEmpty) return null;

    if (_isShuffled) {
      final currentShuffledIndex = _shuffledIndices.indexOf(_currentIndex);
      final nextShuffledIndex =
          (currentShuffledIndex + 1) % _shuffledIndices.length;
      _currentIndex = _shuffledIndices[nextShuffledIndex];
    } else {
      _currentIndex = (_currentIndex + 1) % state.length;
    }

    return state[_currentIndex];
  }

  // Play previous video in playlist
  Video? playPrevious() {
    if (state.isEmpty) return null;

    if (_isShuffled) {
      final currentShuffledIndex = _shuffledIndices.indexOf(_currentIndex);
      final prevShuffledIndex =
          (currentShuffledIndex - 1 + _shuffledIndices.length) %
          _shuffledIndices.length;
      _currentIndex = _shuffledIndices[prevShuffledIndex];
    } else {
      _currentIndex = (_currentIndex - 1 + state.length) % state.length;
    }

    return state[_currentIndex];
  }

  // Get current index
  int getCurrentIndex() {
    return _currentIndex;
  }

  // Set current index
  void setCurrentIndex(int index) {
    if (index >= 0 && index < state.length) {
      _currentIndex = index;
    }
  }
}
