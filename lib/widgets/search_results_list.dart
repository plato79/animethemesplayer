import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../models/audio.dart';
import '../models/video.dart';
import '../providers/playlist_providers.dart';
import '../screens/anime_detail_screen.dart';
import '../screens/playlist_screen.dart';

class SearchResultsList extends ConsumerWidget {
  final List<Anime> results;
  final bool isLoading;

  const SearchResultsList({
    super.key,
    required this.results,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    // Count all audio and video files
    int totalAudioCount = 0;
    int totalVideoCount = 0;

    for (final anime in results) {
      if (anime.animethemes != null) {
        for (final theme in anime.animethemes!) {
          if (theme.animethemeentries == null) continue;

          for (final entry in theme.animethemeentries!) {
            if (entry.videos == null) continue;

            for (final video in entry.videos!) {
              if (video.audio != null) {
                totalAudioCount++;
              } else if (video.link.isNotEmpty) {
                totalVideoCount++;
              }
            }
          }
        }
      }
    }

    return Column(
      children: [
        // Add these buttons only if we have audio or video files
        if (totalAudioCount > 0 || totalVideoCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add all media to playlists',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (totalAudioCount > 0)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.playlist_add),
                            label: Text('Add $totalAudioCount Audios'),
                            onPressed:
                                () => _addAllAudioToPlaylist(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        if (totalVideoCount > 0)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.playlist_add),
                            label: Text('Add $totalVideoCount Videos'),
                            onPressed:
                                () => _addAllVideoToPlaylist(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final anime = results[index];
              return AnimeListItem(anime: anime);
            },
          ),
        ),
      ],
    );
  }

  /// Add all audio files from search results to playlist
  void _addAllAudioToPlaylist(BuildContext context, WidgetRef ref) {
    final List<Audio> allAudio = [];

    // Collect all audio from all animes
    for (final anime in results) {
      final String? animeImageUrl = anime.getLargeCoverImage();

      if (anime.animethemes != null) {
        for (final theme in anime.animethemes!) {
          if (theme.animethemeentries == null) continue;

          for (final entry in theme.animethemeentries!) {
            if (entry.videos == null) continue;

            for (final video in entry.videos!) {
              if (video.audio != null) {
                // Add anime image to audio for better UI
                final audioWithImage = video.audio!.copyWith(
                  animeImageUrl: animeImageUrl,
                );
                allAudio.add(audioWithImage);
              }
            }
          }
        }
      }
    }

    if (allAudio.isNotEmpty) {
      ref.read(audioPlaylistProvider.notifier).addAll(allAudio);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${allAudio.length} audio files to playlist'),
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

  /// Add all videos from search results to playlist
  void _addAllVideoToPlaylist(BuildContext context, WidgetRef ref) {
    final List<Video> allVideos = [];

    // Collect all videos from all animes
    for (final anime in results) {
      if (anime.animethemes != null) {
        for (final theme in anime.animethemes!) {
          if (theme.animethemeentries == null) continue;

          for (final entry in theme.animethemeentries!) {
            if (entry.videos == null) continue;

            for (final video in entry.videos!) {
              if (video.audio == null && video.link.isNotEmpty) {
                allVideos.add(video);
              }
            }
          }
        }
      }
    }

    if (allVideos.isNotEmpty) {
      ref.read(videoPlaylistProvider.notifier).addAll(allVideos);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${allVideos.length} videos to playlist'),
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

class AnimeListItem extends StatelessWidget {
  final Anime anime;

  const AnimeListItem({super.key, required this.anime});

  // Helper method to find image by facet
  String? _getImageUrlByFacet(String facet) {
    if (anime.images == null || anime.images!.isEmpty) return null;

    // Try to find image with specified facet
    final specificImage = anime.images!.firstWhere(
      (img) => img.facet == facet,
      orElse: () => anime.images!.first,
    );
    return specificImage.link;
  }

  @override
  Widget build(BuildContext context) {
    // Get the small cover image if available, or fallback to first image
    final imageUrl = _getImageUrlByFacet('Small Cover');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnimeDetailScreen(anime: anime),
            ),
          );
        },
        // Add LayoutBuilder to make the layout responsive to different screen sizes
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Calculate dimensions based on available width
            final isNarrow = constraints.maxWidth < 350;
            final imageWidth = isNarrow ? 60.0 : 80.0;
            final imageHeight = isNarrow ? 90.0 : 120.0;
            final titleFontSize = isNarrow ? 16.0 : 18.0;
            final contentPadding = isNarrow ? 8.0 : 12.0;

            return Padding(
              padding: EdgeInsets.all(contentPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Anime image or placeholder with responsive dimensions
                  SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child:
                        imageUrl != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                errorWidget:
                                    (context, url, error) =>
                                        const Icon(Icons.error, size: 40),
                              ),
                            )
                            : Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.image_not_supported,
                                size: isNarrow ? 30 : 40,
                              ),
                            ),
                  ),
                  SizedBox(width: isNarrow ? 8 : 16),
                  // Anime info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          anime.name,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isNarrow ? 4 : 8),
                        Text(
                          'Format: ${anime.mediaFormat}',
                          style: TextStyle(
                            fontSize: isNarrow ? 12 : 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: isNarrow ? 4 : 8),
                        // Wrap widget handles the overflow automatically
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildInfoChip(
                              '${anime.animethemes?.length ?? 0} Themes',
                              Icons.music_note,
                              isNarrow,
                            ),
                            _buildInfoChip(
                              'View Details',
                              Icons.arrow_forward,
                              isNarrow,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmall ? 12 : 16),
          SizedBox(width: isSmall ? 2 : 4),
          Text(label, style: TextStyle(fontSize: isSmall ? 10 : 12)),
        ],
      ),
    );
  }
}
