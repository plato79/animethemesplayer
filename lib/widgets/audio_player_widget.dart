import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio.dart';
import '../providers/anime_providers.dart';
import '../providers/playlist_providers.dart';
import '../screens/audio_player_screen.dart'; // Import the AudioPlayerScreen
import 'dart:async';
import 'package:rxdart/rxdart.dart';

// Class to represent the state of the progress bar
class ProgressBarState {
  final Duration current;
  final Duration buffered;
  final Duration total;

  ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });
}

class AnimeAudioPlayer extends ConsumerStatefulWidget {
  final Audio audio;
  final bool isPlaylist;

  const AnimeAudioPlayer({
    super.key,
    required this.audio,
    this.isPlaylist = false,
  });

  @override
  ConsumerState<AnimeAudioPlayer> createState() => _AnimeAudioPlayerState();
}

class _AnimeAudioPlayerState extends ConsumerState<AnimeAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isSeeking = false;
  Duration? _bufferedPosition;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    // We'll no longer initialize audio player here
    // Instead we'll just set up a placeholder until the user navigates to the player screen
    if (!widget.isPlaylist) {
      _loadMetadataOnly();
    } else {
      _initAudio();
    }
  }

  Future<void> _loadMetadataOnly() async {
    try {
      // Just set the duration if available from metadata
      if (widget.audio.link.isNotEmpty) {
        debugPrint('Loading metadata only for: ${widget.audio.link}');
        await _audioPlayer.setUrl(widget.audio.link, preload: true);

        // Wait briefly for metadata
        int attempts = 0;
        while (_audioPlayer.duration == null && attempts < 5) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        // Set duration once available
        final duration = _audioPlayer.duration ?? Duration.zero;
        if (mounted) {
          setState(() {
            _totalDuration = duration;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
    }
  }

  void _openAudioPlayerScreen() {
    try {
      // Stop any playback before navigating
      _audioPlayer.stop();

      // Navigate to the dedicated player screen
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder:
                  (context) => AudioPlayerScreen(
                    initialAudio: widget.audio,
                    isPlaylist:
                        widget.isPlaylist ||
                        ref.read(audioPlaylistProvider).length > 1,
                  ),
            ),
          )
          .catchError((error) {
            debugPrint('Error navigating to audio player screen: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error opening player: ${error.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          });
    } catch (e) {
      debugPrint('Error in _openAudioPlayerScreen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open audio player: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(AnimeAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.audio.id != oldWidget.audio.id) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    try {
      // Reset state
      setState(() {
        _isInitialized = false;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _bufferedPosition = null;
      });

      // Clear global state
      ref.read(currentPositionProvider.notifier).state = Duration.zero;
      ref.read(totalDurationProvider.notifier).state = Duration.zero;

      // Validate URL before attempting to play
      if (widget.audio.link.isEmpty) {
        debugPrint('Error: Empty audio URL');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Audio file URL is empty'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugPrint('Initializing audio player with URL: ${widget.audio.link}');

      // Load and prepare the audio with preload option to get metadata first
      await _audioPlayer.setUrl(widget.audio.link, preload: true);
      debugPrint('Audio URL set successfully');

      // Set up the combined progress stream
      final progressStream = _createProgressStream();

      // Subscribe to the progress stream for state updates
      final progressSubscription = progressStream.listen(
        (progress) {
          if (mounted && !_isSeeking) {
            setState(() {
              _currentPosition = progress.current;
              _bufferedPosition = progress.buffered;
              _totalDuration = progress.total;
            });

            // Update global state providers
            ref.read(currentPositionProvider.notifier).state = progress.current;
            ref.read(totalDurationProvider.notifier).state = progress.total;
          }
        },
        onError: (e) {
          debugPrint('Error in progress stream: $e');
        },
      );

      // Set up disposal of the subscription
      final disposeSub = () {
        progressSubscription.cancel().catchError((error) {
          debugPrint('Error cancelling progress subscription: $error');
        });
      };

      // Listen for playback state changes
      _audioPlayer.playerStateStream.listen(
        (playerState) {
          debugPrint(
            'Audio player state changed: ${playerState.processingState}, playing: ${playerState.playing}',
          );

          // Update the global playing state based on the player state
          if (mounted) {
            ref.read(isPlayingProvider.notifier).state = playerState.playing;
          }

          if (playerState.processingState == ProcessingState.completed) {
            // If we're in playlist mode and playback completes, play the next audio
            if (ref.read(playbackModeProvider) == PlaybackMode.playlist) {
              _playNextInPlaylist();
            } else {
              _audioPlayer.seek(Duration.zero);
              _audioPlayer.pause();
              if (mounted) {
                ref.read(isPlayingProvider.notifier).state = false;
              }
            }
          }
        },
        onError: (e) {
          debugPrint('Error in playerStateStream: $e');
          // Show error notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playback error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      // Wait for duration to be available
      await _audioPlayer.durationStream
          .where((d) => d != null)
          .first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => _audioPlayer.duration ?? Duration.zero,
          );

      // Once everything is set up, mark as initialized
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Wait for some buffer before playing
      debugPrint('Waiting for initial buffer before starting playback...');
      const requiredBufferDuration = Duration(
        seconds: 5,
      ); // Reduced buffer requirement for better UX

      // Show a quiet loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Buffering audio...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Wait for buffer using the progress stream
      try {
        await progressStream
            .where(
              (state) =>
                  state.buffered >= requiredBufferDuration ||
                  (state.total > Duration.zero &&
                      state.buffered >= state.total),
            )
            .first
            .timeout(const Duration(seconds: 8));
        debugPrint('Sufficient buffer achieved, starting playback');
      } catch (e) {
        debugPrint('Buffer timeout or error, starting playback anyway: $e');
      }

      // Start playback
      if (mounted) {
        await _audioPlayer.play().catchError((error) {
          debugPrint('Error playing audio: $error');
          disposeSub();
        });
      } else {
        disposeSub();
      }
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
      // Show error state in UI
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Create a combined stream for progress tracking
  Stream<ProgressBarState> _createProgressStream() {
    return Rx.combineLatest3<Duration, Duration, Duration?, ProgressBarState>(
      _audioPlayer.positionStream,
      _audioPlayer.bufferedPositionStream,
      _audioPlayer.durationStream.where((duration) => duration != null),
      (position, bufferedPosition, duration) {
        return ProgressBarState(
          current: position,
          buffered: bufferedPosition,
          total: duration ?? Duration.zero,
        );
      },
    ).distinct(
      (previous, current) =>
          previous.current.inMilliseconds == current.current.inMilliseconds &&
          previous.buffered.inMilliseconds == current.buffered.inMilliseconds &&
          previous.total.inMilliseconds == current.total.inMilliseconds,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _playNextInPlaylist() {
    final notifier = ref.read(audioPlaylistProvider.notifier);
    final nextAudio = notifier.playNext();

    if (nextAudio != null && mounted) {
      ref.read(selectedAudioProvider.notifier).state = nextAudio;
    }
  }

  void _playPreviousInPlaylist() {
    final notifier = ref.read(audioPlaylistProvider.notifier);
    final prevAudio = notifier.playPrevious();

    if (prevAudio != null && mounted) {
      ref.read(selectedAudioProvider.notifier).state = prevAudio;
    }
  }

  Future<void> _addToPlaylist() async {
    // Add current audio to playlist if it's not already there
    ref.read(audioPlaylistProvider.notifier).addAudio(widget.audio);

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to audio playlist'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // First try to use the image URL stored in the audio object
    // If that's not available, fall back to the current anime image from the provider
    final String? imageUrl = widget.audio.animeImageUrl;
    final currentAnimeImage = imageUrl ?? ref.watch(currentAnimeImageProvider);

    // Check if this audio is in the playlist
    final playlist = ref.watch(audioPlaylistProvider);
    final bool isInPlaylist = playlist.any(
      (item) => item.id == widget.audio.id,
    );

    return GestureDetector(
      onTap: _openAudioPlayerScreen,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with track info and album art
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Album art
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.grey.shade800,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        currentAnimeImage != null
                            ? Image.network(
                              currentAnimeImage,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.music_note,
                                    size: 30,
                                    color: Colors.white54,
                                  ),
                            )
                            : const Icon(
                              Icons.music_note,
                              size: 30,
                              color: Colors.white54,
                            ),
                  ),

                  const SizedBox(width: 12),

                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.audio.basename ?? 'Unknown Track',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Audio Track',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Duration info
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Duration info
                  Text(
                    "Duration: ${_formatDuration(_totalDuration)}",
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),

                  // Play button
                  ElevatedButton.icon(
                    onPressed: _openAudioPlayerScreen,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Add to playlist button
                  OutlinedButton.icon(
                    icon: Icon(
                      isInPlaylist
                          ? Icons.playlist_add_check
                          : Icons.playlist_add,
                      size: 18,
                    ),
                    label: Text(
                      isInPlaylist ? 'In Playlist' : 'Add to Playlist',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: isInPlaylist ? null : _addToPlaylist,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),

                  // Metadata display
                  Text(
                    widget.audio.filename?.split('/').last ?? '',
                    style: TextStyle(
                      fontSize: 10.0,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
