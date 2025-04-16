import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for DeviceOrientation
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../models/video.dart';
import '../providers/anime_providers.dart';
import '../providers/playlist_providers.dart';
import '../screens/video_player_screen.dart';

class AnimeVideoPlayer extends ConsumerStatefulWidget {
  final Video video;
  final bool isPlaylist;
  final bool fullScreen;

  const AnimeVideoPlayer({
    super.key,
    required this.video,
    this.isPlaylist = false,
    this.fullScreen = false,
  });

  @override
  ConsumerState<AnimeVideoPlayer> createState() => _AnimeVideoPlayerState();
}

class _AnimeVideoPlayerState extends ConsumerState<AnimeVideoPlayer> {
  VideoPlayerController?
  _videoPlayerController; // Changed from late to nullable
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _localIsPlaying = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _retryCount = 0;
  final int _maxRetries = 3;
  bool _disposed = false; // Track disposal state

  // For network connectivity monitoring
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _monitorConnectivity();
    _initializePlayer();
  }

  void _monitorConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      connectivityResults,
    ) {
      final wasConnected = _isConnected;
      _isConnected = !connectivityResults.contains(ConnectivityResult.none);

      // If connection was restored and we had an error, retry initialization
      if (_isConnected && !wasConnected && _hasError) {
        debugPrint("Connection restored. Retrying video initialization...");
        _retryInitialization();
      }
    });
  }

  Future<void> _initializePlayer() async {
    try {
      if (!mounted || _disposed) return;

      // Check connectivity before attempting to load video
      final connectivityResults = await Connectivity().checkConnectivity();
      if (connectivityResults.isEmpty ||
          connectivityResults.contains(ConnectivityResult.none)) {
        setState(() {
          _hasError = true;
          _errorMessage = "No internet connection. Please check your network.";
        });
        return;
      }

      debugPrint("Initializing video player with link: ${widget.video.link}");

      // Initialize with better error handling and platform-specific settings
      final videoUri = Uri.parse(widget.video.link);
      _videoPlayerController = VideoPlayerController.networkUrl(
        videoUri,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true, // Allow mixing with other audio
          allowBackgroundPlayback: false,
        ),
        formatHint: _getFormatHintFromUrl(widget.video.link),
        httpHeaders: {'User-Agent': 'AnimeThemesMediaPlayer/1.0'},
      );

      // Set up error listener before initialization
      _videoPlayerController?.addListener(_videoPlayerListener);

      // Show loading state
      setState(() {
        _hasError = false;
        _isInitialized = false;
      });

      // Use a timeout with proper error handling
      bool initializationSuccessful = false;
      try {
        await _videoPlayerController?.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Video initialization timed out');
          },
        );
        initializationSuccessful = true;
      } catch (initError) {
        debugPrint("Error during video initialization: $initError");

        if (!mounted || _disposed) return;

        // Try with software rendering if hardware decoding fails
        if (_videoPlayerController != null) {
          try {
            await _videoPlayerController!.dispose();

            _videoPlayerController = VideoPlayerController.networkUrl(
              videoUri,
              videoPlayerOptions: VideoPlayerOptions(
                mixWithOthers: true,
                allowBackgroundPlayback: false,
              ),
              httpHeaders: {'User-Agent': 'AnimeThemesMediaPlayer/1.0'},
            );

            _videoPlayerController?.addListener(_videoPlayerListener);

            await _videoPlayerController?.initialize().timeout(
              const Duration(seconds: 15),
            );

            initializationSuccessful = true;
            debugPrint("Successfully initialized with fallback method");
          } catch (fallbackError) {
            debugPrint("Fallback initialization also failed: $fallbackError");
            rethrow; // Use rethrow instead of throw fallbackError
          }
        }
      }

      if (!mounted || _disposed) return;

      if (!initializationSuccessful) {
        throw Exception("Failed to initialize video player after retries");
      }

      // Create Chewie controller with more robust settings
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: widget.fullScreen, // Only autoplay in fullscreen mode
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Error: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _retryInitialization,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        },
        allowPlaybackSpeedChanging: true,
        allowMuting: true,
        placeholder: const Center(child: CircularProgressIndicator()),
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.grey[300]!,
          bufferedColor: Colors.grey.shade500,
        ),
        // Show controls in full screen mode
        showControls: widget.fullScreen,
        // Allow proper fullscreen now
        allowFullScreen: true,
        // Set device orientation based on video aspect ratio when entering fullscreen
        deviceOrientationsOnEnterFullScreen: _getPreferredOrientations(),
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      );

      setState(() {
        _isInitialized = true;
        _localIsPlaying = widget.fullScreen;
        _hasError = false;
      });

      // Update global playing state if in full screen
      if (widget.fullScreen && mounted && !_disposed) {
        ref.read(isPlayingProvider.notifier).state = true;
      }

      // Update position and duration providers for consistent UI
      _videoPlayerController?.addListener(() {
        if (!mounted || _disposed) return;

        // Update position provider
        ref.read(currentPositionProvider.notifier).state =
            _videoPlayerController!.value.position;

        // Update duration provider once we know it
        if (_videoPlayerController!.value.duration != Duration.zero) {
          ref.read(totalDurationProvider.notifier).state =
              _videoPlayerController!.value.duration;
        }

        // Handle video completion for playlist
        if (_videoPlayerController!.value.position >=
                _videoPlayerController!.value.duration &&
            widget.isPlaylist &&
            widget.fullScreen) {
          // Video finished playing - move to next in playlist
          _playNextInPlaylist();
        }
      });
    } catch (e) {
      if (!mounted || _disposed) return;

      debugPrint('Error initializing video player: $e');
      setState(() {
        _isInitialized = false;
        _hasError = true;
        _errorMessage = e.toString();
      });

      // Attempt retry if we haven't exceeded max retries
      if (_retryCount < _maxRetries) {
        _scheduleRetry();
      }
    }
  }

  // Determine best orientations based on video aspect ratio
  List<DeviceOrientation> _getPreferredOrientations() {
    if (_videoPlayerController == null) {
      return [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ];
    }

    final aspectRatio = _videoPlayerController!.value.aspectRatio;

    // If aspect ratio is wider than tall, prefer landscape
    if (aspectRatio > 1.0) {
      return [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    } else {
      return [DeviceOrientation.portraitUp];
    }
  }

  // Helper method to determine format hint from URL
  VideoFormat? _getFormatHintFromUrl(String url) {
    if (url.endsWith('.webm')) {
      return VideoFormat.other;
    } else if (url.endsWith('.mp4')) {
      return VideoFormat.dash;
    } else if (url.endsWith('.m3u8')) {
      return VideoFormat.hls;
    }
    return null;
  }

  void _scheduleRetry() {
    _retryCount++;
    Future.delayed(Duration(seconds: _retryCount), () {
      if (mounted && !_disposed) {
        debugPrint('Retry attempt $_retryCount for video player');
        _retryInitialization();
      }
    });
  }

  void _retryInitialization() {
    // Clean up existing controller before retry
    try {
      _videoPlayerController?.removeListener(_videoPlayerListener);
      _videoPlayerController?.dispose();
      _chewieController?.dispose();
    } catch (e) {
      debugPrint('Error during cleanup before retry: $e');
    }

    // Reset state
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = '';
      _localIsPlaying = false;
    });

    // Attempt initialization again
    _initializePlayer();
  }

  void _playNextInPlaylist() {
    final nextVideo = ref.read(videoPlaylistProvider.notifier).playNext();
    if (nextVideo != null) {
      // Update the selected media
      ref.read(selectedMediaProvider.notifier).state = nextVideo;

      // If in full screen mode, navigate to the next video
      if (widget.fullScreen && mounted && !_disposed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) =>
                    VideoPlayerScreen(video: nextVideo, isPlaylist: true),
          ),
        );
      }
    }
  }

  void _playPreviousInPlaylist() {
    final prevVideo = ref.read(videoPlaylistProvider.notifier).playPrevious();
    if (prevVideo != null) {
      // Update the selected media
      ref.read(selectedMediaProvider.notifier).state = prevVideo;

      // If in full screen mode, navigate to the previous video
      if (widget.fullScreen && mounted && !_disposed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) =>
                    VideoPlayerScreen(video: prevVideo, isPlaylist: true),
          ),
        );
      }
    }
  }

  void _videoPlayerListener() {
    // Store the current playing state in a local variable first
    final bool isPlaying = _videoPlayerController?.value.isPlaying ?? false;

    // Update local state
    if (_localIsPlaying != isPlaying) {
      if (mounted && !_disposed) {
        setState(() {
          _localIsPlaying = isPlaying;
        });
      }
    }

    // Only update provider state if widget is still mounted
    if (mounted && !_disposed && widget.isPlaylist) {
      // Instead of directly using ref here, check if we're mounted
      if (_videoPlayerController?.value.isCompleted ?? false) {
        if (mounted && !_disposed) {
          // Schedule this for the next frame to avoid disposal issues
          Future.microtask(() {
            if (mounted && !_disposed) {
              // Now it's safe to use ref
              final playlistNotifier = ref.read(videoPlaylistProvider.notifier);
              playlistNotifier.playNext();
            }
          });
        }
      }
    }
  }

  void _openFullScreenPlayer() {
    // Pause current preview playback
    _videoPlayerController?.pause();

    // Add current video to playlist if not already in it
    ref.read(videoPlaylistProvider.notifier).addVideo(widget.video);

    // Set as the selected media
    ref.read(selectedMediaProvider.notifier).state = widget.video;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => VideoPlayerScreen(
              video: widget.video,
              isPlaylist:
                  widget.isPlaylist ||
                  ref.read(videoPlaylistProvider).length > 1,
            ),
      ),
    );
  }

  @override
  void dispose() {
    // Make sure to dispose controllers first
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    // Cancel connectivity subscription to prevent memory leaks
    _connectivitySubscription.cancel();

    _disposed = true;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInPlaylist = widget.isPlaylist;
    final playlist = ref.watch(videoPlaylistProvider);
    final isShuffled = ref.watch(isShuffledProvider);

    // For list view, show a thumbnail with play button
    if (!widget.fullScreen) {
      return GestureDetector(
        onTap: _openFullScreenPlayer,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Thumbnail or first frame
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.black,
              child:
                  _hasError
                      ? Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.red[300],
                          size: 40,
                        ),
                      )
                      : widget.video.basename != null
                      ? Center(
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 120,
                          height: 120,
                          color: Color.fromRGBO(255, 255, 255, 0.4),
                        ),
                      )
                      : const Center(child: CircularProgressIndicator()),
            ),
            // Play button overlay
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
            // Video title
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Color.fromRGBO(0, 0, 0, 0.6),
                child: Text(
                  widget.video.basename ?? 'Unknown',
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Full screen player
    return Stack(
      children: [
        Container(
          color: Colors.black,
          child:
              _isInitialized && _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : _hasError
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _retryInitialization,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                  : const Center(child: CircularProgressIndicator()),
        ),
        // Network connectivity warning
        if (!_isConnected)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Color.fromRGBO(255, 0, 0, 0.8),
              child: const Text(
                'No internet connection. Playback may be affected.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        // Back button in the top left corner - ONLY in direct fullscreen mode (not when in a page with AppBar)
        // This ensures we don't have duplicate back buttons
        if (widget.fullScreen && ModalRoute.of(context)?.canPop == false)
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(0, 0, 0, 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  onPressed: () {
                    // Stop playback and close the fullscreen view
                    _videoPlayerController?.pause();
                    Navigator.of(context).pop();
                  },
                  tooltip: 'Back',
                ),
              ),
            ),
          ),
        // Playlist controls overlay - ONLY in fullscreen and if part of playlist
        if (widget.fullScreen && isInPlaylist)
          Positioned(
            bottom: 60, // Position above the chewie controls
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withAlpha(128),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: _playPreviousInPlaylist,
                  ),
                  Text(
                    '${playlist.contains(widget.video) ? playlist.indexOf(widget.video) + 1 : 0} / ${playlist.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color:
                          isShuffled
                              ? Colors.white
                              : Colors.white.withAlpha(153),
                    ),
                    onPressed: () {
                      ref.read(isShuffledProvider.notifier).state = !isShuffled;
                      ref.read(videoPlaylistProvider.notifier).toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _playNextInPlaylist,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
