import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../models/anime_theme.dart';
import '../models/anime_theme_entry.dart';
import '../models/video.dart';
import '../models/audio.dart';
import '../providers/anime_providers.dart';
import '../providers/playlist_providers.dart';
import '../widgets/full_screen_image_view.dart'; // Import the new widget
import 'playlist_screen.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';

class AnimeDetailScreen extends ConsumerStatefulWidget {
  final Anime anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen> {
  // Create a unique hero tag for this anime's image
  late final String _heroTag;

  @override
  void initState() {
    super.initState();

    // Generate a unique hero tag using the anime ID
    _heroTag = 'anime_cover_${widget.anime.id}';

    // Set the current anime and its image for the providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentAnimeProvider.notifier).state = widget.anime;

      // Set anime image using small cover for UI previews
      final smallCoverImage = widget.anime.getSmallCoverImage();
      if (smallCoverImage != null) {
        ref.read(currentAnimeImageProvider.notifier).state = smallCoverImage;
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Count the number of audio and video files in this anime
    int audioCount = 0;
    int videoCount = 0;

    if (widget.anime.animethemes != null) {
      for (final theme in widget.anime.animethemes!) {
        if (theme.animethemeentries == null) continue;

        for (final entry in theme.animethemeentries!) {
          if (entry.videos == null) continue;

          for (final video in entry.videos!) {
            if (video.audio != null) {
              audioCount++;
            } else {
              videoCount++;
            }
          }
        }
      }
    }

    // Get the image URL
    final imageUrl =
        widget.anime.getLargeCoverImage() ??
        (widget.anime.images?.isNotEmpty == true
            ? widget.anime.images!.first.link
            : null);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.anime.name),
        actions: [
          // Add playlist button
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaylistScreen()),
              );
            },
            tooltip: 'View Playlists',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with anime image if available
          if (imageUrl != null)
            Stack(
              children: [
                // Image with Hero widget
                GestureDetector(
                  onTap: () => _openFullScreenImage(context, imageUrl),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Hero(
                      tag: _heroTag,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        errorWidget:
                            (context, url, error) => const Center(
                              child: Icon(Icons.error, size: 40),
                            ),
                      ),
                    ),
                  ),
                ),
                // View full image indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(153),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to zoom',
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Add to playlist buttons overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (audioCount > 0)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.playlist_add),
                          label: Text(
                            'Add $audioCount Audio${audioCount > 1 ? 's' : ''}',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withAlpha(179),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _addAllAudioToPlaylist(context),
                        ),
                      const SizedBox(width: 8),
                      if (videoCount > 0)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.playlist_add),
                          label: Text(
                            'Add $videoCount Video${videoCount > 1 ? 's' : ''}',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withAlpha(179),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _addAllVideosToPlaylist(context),
                        ),
                    ],
                  ),
                ),
              ],
            ),

          // List of available themes
          Expanded(
            child:
                widget.anime.animethemes?.isNotEmpty == true
                    ? ListView.builder(
                      itemCount: widget.anime.animethemes!.length,
                      padding: const EdgeInsets.all(8.0),
                      itemBuilder: (context, index) {
                        final theme = widget.anime.animethemes![index];
                        return ThemeCard(theme: theme);
                      },
                    )
                    : Center(
                      child: Text(
                        'No themes available for ${widget.anime.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // Open full screen image
  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder:
            (_, __, ___) =>
                FullScreenImageView(imageUrl: imageUrl, heroTag: _heroTag),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Add all audio files from this anime to the playlist
  void _addAllAudioToPlaylist(BuildContext context) {
    final List<Audio> audioFiles = [];

    // Get the anime Large Cover image for better playback quality
    final String? animeImageUrl = widget.anime.getLargeCoverImage();

    // Extract all audio files from the anime's themes
    if (widget.anime.animethemes != null) {
      for (final theme in widget.anime.animethemes!) {
        if (theme.animethemeentries == null) continue;

        for (final entry in theme.animethemeentries!) {
          if (entry.videos == null) continue;

          for (final video in entry.videos!) {
            if (video.audio != null) {
              // Create a new Audio object with the anime image URL
              final audioWithImage = video.audio!.copyWith(
                animeImageUrl: animeImageUrl,
              );
              audioFiles.add(audioWithImage);
            }
          }
        }
      }
    }

    if (audioFiles.isNotEmpty) {
      ref.read(audioPlaylistProvider.notifier).addAll(audioFiles);

      // Show confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${audioFiles.length} audio files to playlist'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaylistScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  // Add all video files from this anime to the playlist
  void _addAllVideosToPlaylist(BuildContext context) {
    final List<Video> videoFiles = [];

    // Extract all video files from the anime's themes
    if (widget.anime.animethemes != null) {
      for (final theme in widget.anime.animethemes!) {
        if (theme.animethemeentries == null) continue;

        for (final entry in theme.animethemeentries!) {
          if (entry.videos == null) continue;

          for (final video in entry.videos!) {
            if (video.audio == null && video.link.isNotEmpty) {
              videoFiles.add(video);
            }
          }
        }
      }
    }

    if (videoFiles.isNotEmpty) {
      ref.read(videoPlaylistProvider.notifier).addAll(videoFiles);

      // Show confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${videoFiles.length} videos to playlist'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaylistScreen()),
              );
            },
          ),
        ),
      );
    }
  }
}

class ThemeCard extends StatelessWidget {
  final AnimeTheme theme;

  const ThemeCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final entries = theme.animethemeentries;
    final themeTitle =
        '${theme.type ?? 'Theme'}${theme.sequence != null ? ' ${theme.sequence}' : ''}: ${theme.slug}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              themeTitle,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Type: ${theme.type ?? 'Unknown'}',
              style: TextStyle(fontSize: 14.0, color: Colors.grey[600]),
            ),
            if (entries?.isNotEmpty == true) ...[
              const SizedBox(height: 12.0),
              const Text(
                'Versions',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
              ),
              ...entries!.map((entry) => EntryItem(entry: entry)).toList(),
            ],
          ],
        ),
      ),
    );
  }
}

class EntryItem extends ConsumerWidget {
  final AnimeThemeEntry entry;

  const EntryItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the current anime and its image if available
    final currentAnime = ref.watch(currentAnimeProvider);
    // Get the Large Cover image for playback for better quality
    final String? animeImageUrl = currentAnime?.getLargeCoverImage();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Version ${entry.version ?? "1"}',
            style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500),
          ),
        ),
        if (entry.videos?.isNotEmpty == true)
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children:
                entry.videos!.expand((video) {
                  final List<Widget> buttons = [];

                  // Always show video button if link is available
                  if (video.link.isNotEmpty) {
                    // Format info for video (WEBM)
                    final String format =
                        video.link.toLowerCase().endsWith('.webm')
                            ? 'WEBM'
                            : '';
                    final String videoLabel =
                        video.resolution != null
                            ? '${video.resolution}p${format.isNotEmpty ? ' $format' : ''}'
                            : 'Video${format.isNotEmpty ? ' ($format)' : ''}';

                    // Create video button
                    buttons.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(
                                Icons.movie,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              label: Text(
                                videoLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                              ),
                              onPressed: () {
                                // First stop any currently playing media
                                ref.read(isPlayingProvider.notifier).state =
                                    false;

                                // Clear previous selections
                                ref.read(selectedAudioProvider.notifier).state =
                                    null;
                                ref.read(selectedMediaProvider.notifier).state =
                                    null;

                                // Navigate to dedicated video player screen
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => VideoPlayerScreen(
                                          video: video,
                                          isPlaylist: false,
                                        ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.playlist_add),
                              tooltip: 'Add video to playlist',
                              onPressed: () {
                                // Add video to playlist
                                ref
                                    .read(videoPlaylistProvider.notifier)
                                    .addVideo(video);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Video added to playlist',
                                    ),
                                    action: SnackBarAction(
                                      label: 'View',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const PlaylistScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Add audio button if audio is available
                  if (video.audio != null && video.audio!.link.isNotEmpty) {
                    buttons.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(
                                Icons.music_note,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              label: const Text(
                                'Audio',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                              ),
                              onPressed: () {
                                // First stop any currently playing media to avoid conflicts
                                ref.read(isPlayingProvider.notifier).state =
                                    false;

                                // Clear previous selections
                                ref.read(selectedAudioProvider.notifier).state =
                                    null;
                                ref.read(selectedMediaProvider.notifier).state =
                                    null;

                                // Create a new audio object with the image URL
                                final audioWithImage = video.audio!.copyWith(
                                  animeImageUrl: animeImageUrl,
                                );

                                // Open the dedicated audio player screen
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => AudioPlayerScreen(
                                          initialAudio: audioWithImage,
                                          isPlaylist: false,
                                        ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.playlist_add),
                              tooltip: 'Add audio to playlist',
                              onPressed: () {
                                // Create new audio object with image URL
                                final audioWithImage = video.audio!.copyWith(
                                  animeImageUrl: animeImageUrl,
                                );

                                // Add audio to playlist
                                ref
                                    .read(audioPlaylistProvider.notifier)
                                    .addAudio(audioWithImage);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Audio added to playlist',
                                    ),
                                    action: SnackBarAction(
                                      label: 'View',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const PlaylistScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return buttons;
                }).toList(),
          )
        else
          const Text('No videos available for this version'),
        const Divider(),
      ],
    );
  }
}
