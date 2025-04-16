import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio.dart';
import '../providers/anime_providers.dart';
import '../providers/playlist_providers.dart';
import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';

// A class that combines multiple stream values for progress bar
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

// Custom slider track shape to fix alignment issues
class SliderCustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.0;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;

    // Make sure the track is centered and exactly matches the height of our colored bars
    return Rect.fromLTWH(
      offset.dx + 8, // Match the margin we added to the containers
      trackTop,
      parentBox.size.width - 16, // Account for margins on both sides
      trackHeight,
    );
  }
}

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final Audio initialAudio;
  final bool isPlaylist;

  const AudioPlayerScreen({
    super.key,
    required this.initialAudio,
    this.isPlaylist = false,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with AutomaticKeepAliveClientMixin {
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _disposed = false;
  bool _isLoadingNext = false;
  bool _isSeeking = false;
  double _playbackRate = 1.0;

  // Improved stream handling for progress
  Stream<ProgressBarState>? _progressBarStream;
  // Add this to maintain state during playlist navigation
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioSession();

    // Set initial audio in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentPlayingAudioProvider.notifier).state =
          widget.initialAudio;
      // Set the playback mode based on isPlaylist
      if (widget.isPlaylist) {
        ref.read(playbackModeProvider.notifier).state = PlaybackMode.playlist;
      }
    });

    _initAudio();
  }

  // Set up audio session for better audio handling
  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Listen to system interruptions and respond accordingly
      session.interruptionEventStream.listen(
        (event) {
          if (_disposed) return; // Prevent updates after disposal

          if (event.begin) {
            // Audio was interrupted, pause playback
            if (_isPlaying) {
              _audioPlayer.pause();
              if (mounted) {
                setState(() {
                  _isPlaying = false;
                });
              }
            }
          } else {
            // Interruption ended, you can optionally resume playback
            switch (event.type) {
              case AudioInterruptionType.pause:
              case AudioInterruptionType.duck:
              case AudioInterruptionType.unknown:
                // For these interruption types, let the user decide to resume
                break;
            }
          }
        },
        onError: (error) {
          debugPrint('Audio session interruption error: $error');
        },
        onDone: () {
          debugPrint('Audio session interruption stream closed');
        },
      );
    } catch (e) {
      debugPrint('Error setting up audio session: $e');
      // Continue anyway - the player might still work without proper audio session
    }
  }

  // Create the combined stream for progress tracking
  Stream<ProgressBarState> _createProgressStream(AudioPlayer player) {
    return Rx.combineLatest2<Duration, Duration?, ProgressBarState>(
      player.positionStream,
      player.durationStream.where((duration) => duration != null),
      (position, duration) {
        return ProgressBarState(
          current: position,
          buffered: player.bufferedPosition,
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

  Future<void> _seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    if (!_isInitialized) return;

    try {
      debugPrint('Seeking to position: ${position.inSeconds} seconds');
      await _seek(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  @override
  void didUpdateWidget(AudioPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if we need to update the audio source
    final currentAudio = ref.read(currentPlayingAudioProvider);
    if (currentAudio != null && currentAudio.id != oldWidget.initialAudio.id) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    if (_disposed) return;

    try {
      // Reset state
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _isPlaying = false;
          _isLoadingNext = true;
        });
      }

      // Get the current audio from provider (or use initial audio if provider is empty)
      final currentAudio =
          ref.read(currentPlayingAudioProvider) ?? widget.initialAudio;

      // Validate URL before attempting to play
      if (currentAudio.link.isEmpty) {
        debugPrint('Error: Empty audio URL');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Audio file URL is empty'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoadingNext = false;
          });
        }
        return;
      }

      debugPrint('Initializing audio player with URL: ${currentAudio.link}');

      // Stop current audio before loading a new one
      await _audioPlayer.stop();

      // Single loading approach: load the URL once with preload to get metadata and buffer simultaneously
      await _audioPlayer.setUrl(currentAudio.link, preload: true);
      debugPrint('Audio source set, initializing streams...');

      // Set up progress stream after audio source is loaded
      _progressBarStream = _createProgressStream(_audioPlayer);

      // Listen for playback state changes
      _audioPlayer.playerStateStream.listen(
        (playerState) {
          debugPrint(
            'Audio player state changed: ${playerState.processingState}, playing: ${playerState.playing}',
          );

          if (!mounted || _disposed) return;

          // Update playing state
          if (_isPlaying != playerState.playing) {
            setState(() {
              _isPlaying = playerState.playing;
            });
          }

          // Handle completed audio
          if (playerState.processingState == ProcessingState.completed) {
            final playbackMode = ref.read(playbackModeProvider);
            if (playbackMode == PlaybackMode.playlist) {
              _playNextInPlaylist(autoPlay: true);
            } else {
              _audioPlayer.seek(Duration.zero);
              _audioPlayer.pause();
              if (mounted && !_disposed) {
                setState(() {
                  _isPlaying = false;
                });
              }
            }
          } else if (playerState.processingState == ProcessingState.ready) {
            if (mounted && !_disposed) {
              setState(() {
                _isInitialized = true;
                _isLoadingNext = false;
              });
            }
          }
        },
        onError: (e) {
          debugPrint('Error in playerStateStream: $e');
          if (mounted && !_disposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playback error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      // Get duration info once available
      final duration = _audioPlayer.duration;
      if (duration != null && mounted && !_disposed) {
        debugPrint(
          'Audio metadata loaded. Duration: ${duration.inSeconds} seconds',
        );
        setState(() {
          _isInitialized = true;
        });
      } else {
        // Wait for duration if not immediately available
        _audioPlayer.durationStream.first
            .then((duration) {
              if (duration != null && mounted && !_disposed) {
                debugPrint(
                  'Audio duration received from stream: ${duration.inSeconds} seconds',
                );
                setState(() {
                  _isInitialized = true;
                });
              }
            })
            .catchError((error) {
              debugPrint('Error getting duration: $error');
            });
      }

      // Wait for reasonable buffer before playing (reduced from 10 to 3 seconds for better UX)
      debugPrint('Waiting for buffer before starting playback...');
      const requiredBufferDuration = Duration(seconds: 3);

      // Use a single quiet loading indicator instead of multiple snackbars
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Buffering audio...'),
            ],
          ),
          duration: Duration(seconds: 5),
        ),
      );

      // A more controlled buffering loop that checks mounted state
      bool cancelBuffering = false;
      int bufferAttempts = 0;
      const maxBufferAttempts = 40; // Max ~8 seconds of buffering attempts

      Future<void> checkBuffering() async {
        while (bufferAttempts < maxBufferAttempts &&
            !cancelBuffering &&
            !_disposed) {
          // Check if widget is still active
          if (!mounted) {
            debugPrint('Widget unmounted during buffering, canceling...');
            break;
          }

          // Check current buffer level
          final buffered = _audioPlayer.bufferedPosition;
          final currentPosition = _audioPlayer.position;
          final bufferTarget = currentPosition + requiredBufferDuration;
          final totalDuration = _audioPlayer.duration ?? Duration.zero;

          // If we have enough buffered ahead or reached the end of track, we can start
          if (buffered >= bufferTarget ||
              (totalDuration != Duration.zero && buffered >= totalDuration)) {
            debugPrint(
              'Sufficient buffer achieved: ${_formatDuration(buffered)}',
            );
            break;
          }

          // Show buffer progress in debug every second
          if (bufferAttempts % 5 == 0) {
            debugPrint(
              'Buffering: ${_formatDuration(buffered)} / ${_formatDuration(bufferTarget)} (Total: ${_formatDuration(totalDuration)})',
            );
          }

          await Future.delayed(const Duration(milliseconds: 200));
          bufferAttempts++;
        }

        // Start playback only if we're still mounted and not canceled
        if (!cancelBuffering && mounted && !_disposed) {
          // Start playback
          debugPrint('Starting playback after buffer');
          await _audioPlayer.play().catchError((error) {
            debugPrint('Error playing audio: $error');
          });

          if (mounted && !_disposed) {
            setState(() {
              _isPlaying = true;
              _isLoadingNext = false;
            });
          }
        }
      }

      // Start buffering check
      checkBuffering();

      // Register a disposal callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) {
          cancelBuffering = true;
        }
      });
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
      if (!mounted || _disposed) return;

      setState(() {
        _isInitialized = false;
        _isLoadingNext = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play audio: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _audioPlayer.pause().then((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
    } else {
      _audioPlayer.play().then((_) {
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      });
    }
  }

  void _playNextInPlaylist({bool autoPlay = false}) {
    if (_isLoadingNext) return;

    setState(() {
      _isLoadingNext = true;
    });

    final notifier = ref.read(audioPlaylistProvider.notifier);
    final nextAudio = notifier.playNext();

    if (nextAudio != null && mounted && !_disposed) {
      // Update the current audio in the provider instead of navigating to a new screen
      ref.read(currentPlayingAudioProvider.notifier).state = nextAudio;
      _initAudio();
    } else {
      setState(() {
        _isLoadingNext = false;
      });

      // Show message when we're at the end of playlist
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End of playlist reached'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _playPreviousInPlaylist() {
    if (_isLoadingNext) return;

    setState(() {
      _isLoadingNext = true;
    });

    final notifier = ref.read(audioPlaylistProvider.notifier);
    final prevAudio = notifier.playPrevious();

    if (prevAudio != null && mounted && !_disposed) {
      // Update the current audio in the provider instead of navigating to a new screen
      ref.read(currentPlayingAudioProvider.notifier).state = prevAudio;
      _initAudio();
    } else {
      setState(() {
        _isLoadingNext = false;
      });

      // Show message when we're at the beginning of playlist
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beginning of playlist reached'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _addToPlaylist() async {
    // Get the current audio from provider
    final currentAudio =
        ref.read(currentPlayingAudioProvider) ?? widget.initialAudio;
    ref.read(audioPlaylistProvider.notifier).addAudio(currentAudio);

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

  // Provides visual feedback when seeking
  void _seekToPosition(Duration position) {
    // Create a temporary state update for immediate visual feedback
    setState(() {
      // We'll let the streams update naturally after the seek completes
    });
    seekTo(position);
  }

  void _changePlaybackRate() {
    // Cycle between common playback rates: 0.75x, 1x, 1.25x, 1.5x, 2x
    const rates = [0.75, 1.0, 1.25, 1.5, 2.0];
    int currentIndex = rates.indexOf(_playbackRate);
    int nextIndex = (currentIndex + 1) % rates.length;

    setState(() {
      _playbackRate = rates[nextIndex];
    });

    _audioPlayer.setSpeed(_playbackRate);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playback speed: ${_playbackRate}x'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Watch for changes to the current audio in the provider
    final currentAudio =
        ref.watch(currentPlayingAudioProvider) ?? widget.initialAudio;
    final playbackMode = ref.watch(playbackModeProvider);

    // Check if this audio is in the playlist
    final playlist = ref.watch(audioPlaylistProvider);
    final bool isInPlaylist = playlist.any(
      (item) => item.id == currentAudio.id,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          // Playback rate control
          IconButton(
            icon: Text(
              "${_playbackRate}x",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onPressed: _changePlaybackRate,
            tooltip: 'Change playback speed',
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed:
                playbackMode == PlaybackMode.playlist
                    ? null
                    : () {
                      final notifier = ref.read(audioPlaylistProvider.notifier);
                      if (!isInPlaylist) {
                        notifier.addAudio(currentAudio);
                      }
                      ref.read(playbackModeProvider.notifier).state =
                          PlaybackMode.playlist;
                    },
            tooltip:
                playbackMode == PlaybackMode.playlist
                    ? 'Currently in playlist mode'
                    : 'Switch to playlist mode',
          ),
        ],
      ),
      body: Column(
        children: [
          // Album art - takes up top third of screen
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  // Main image
                  Hero(
                    tag: currentAudio.id, // ?? 'audio-cover',
                    child: Center(
                      child:
                          currentAudio.animeImageUrl != null
                              ? Image.network(
                                currentAudio.animeImageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.music_note,
                                        size: 80,
                                        color: Colors.white54,
                                      ),
                                    ),
                              )
                              : const Center(
                                child: Icon(
                                  Icons.music_note,
                                  size: 80,
                                  color: Colors.white54,
                                ),
                              ),
                    ),
                  ),
                  // Loading indicator overlay
                  if (_isLoadingNext)
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),

          // Player controls - takes up bottom two-thirds
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Track title and info
                  Text(
                    currentAudio.basename ?? 'Unknown Track',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentAudio.filename ?? 'Unknown Source',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Progress bar with timestamps - improved with stream builder
                  if (_progressBarStream != null)
                    StreamBuilder<ProgressBarState>(
                      stream: _progressBarStream,
                      builder: (context, snapshot) {
                        final progressState =
                            snapshot.data ??
                            ProgressBarState(
                              current: Duration.zero,
                              buffered: Duration.zero,
                              total: Duration.zero,
                            );

                        return Column(
                          children: [
                            // Progress bar with buffer indicators
                            Container(
                              height: 36, // Container for touch area
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background track (gray)
                                  Positioned.fill(
                                    child: Center(
                                      child: Container(
                                        height: 4.0, // Fixed height
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.grey.shade800
                                                  : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Buffered portion (slightly lighter gray)
                                  if (progressState.total.inMilliseconds > 0)
                                    Positioned.fill(
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor:
                                            progressState
                                                .buffered
                                                .inMilliseconds /
                                            progressState.total.inMilliseconds,
                                        child: Center(
                                          child: Container(
                                            height:
                                                4.0, // Must match background
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.grey.shade600
                                                      : Colors.grey.shade400,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Played portion (blue) - adjusted position for alignment with circle thumb
                                  if (progressState.total.inMilliseconds > 0)
                                    Positioned.fill(
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor:
                                            progressState
                                                .current
                                                .inMilliseconds /
                                            progressState.total.inMilliseconds,
                                        child: Center(
                                          child: Container(
                                            height: 4.0,
                                            // Fix alignment by using same margins as background
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Slider for user interaction (transparent track)
                                  Positioned.fill(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4.0,
                                        trackShape: SliderCustomTrackShape(),
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 8.0,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 16.0,
                                            ),
                                        activeTrackColor: Colors.transparent,
                                        inactiveTrackColor: Colors.transparent,
                                        thumbColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        overlayColor: Theme.of(
                                          context,
                                        ).colorScheme.primary.withAlpha(80),
                                      ),
                                      child: Slider(
                                        min: 0.0,
                                        max:
                                            progressState.total.inMilliseconds >
                                                    0
                                                ? progressState
                                                    .total
                                                    .inMilliseconds
                                                    .toDouble()
                                                : 1.0,
                                        // Ensure both indicators show the same position
                                        value:
                                            _isSeeking
                                                ? progressState
                                                    .current
                                                    .inMilliseconds
                                                    .toDouble()
                                                : progressState
                                                        .current
                                                        .inMilliseconds >
                                                    progressState
                                                        .total
                                                        .inMilliseconds
                                                ? progressState
                                                    .total
                                                    .inMilliseconds
                                                    .toDouble()
                                                : progressState
                                                    .current
                                                    .inMilliseconds
                                                    .toDouble(),
                                        onChanged: (value) {
                                          final position = Duration(
                                            milliseconds: value.round(),
                                          );
                                          _seekToPosition(position);
                                        },
                                        onChangeStart: (_) {
                                          setState(() {
                                            _isSeeking = true;
                                          });
                                        },
                                        onChangeEnd: (value) {
                                          final position = Duration(
                                            milliseconds: value.round(),
                                          );
                                          _seekToPosition(position);
                                          setState(() {
                                            _isSeeking = false;
                                          });
                                          if (_isPlaying) {
                                            _audioPlayer.play();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Time indicators
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(progressState.current)),
                                  Text(_formatDuration(progressState.total)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // Transport controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Previous button (only visible in playlist mode)
                      if (playbackMode == PlaybackMode.playlist)
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 36),
                          onPressed:
                              _isLoadingNext ? null : _playPreviousInPlaylist,
                        )
                      else
                        const SizedBox(width: 48), // Placeholder for spacing
                      // Play/Pause button
                      IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 64,
                        ),
                        onPressed: _isInitialized ? _togglePlayback : null,
                      ),

                      // Next button (only visible in playlist mode)
                      if (playbackMode == PlaybackMode.playlist)
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 36),
                          onPressed:
                              _isLoadingNext ? null : _playNextInPlaylist,
                        )
                      else
                        // Add to playlist button
                        IconButton(
                          icon: const Icon(Icons.playlist_add, size: 36),
                          onPressed: _addToPlaylist,
                          tooltip: 'Add to playlist',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
