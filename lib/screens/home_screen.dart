import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../providers/anime_providers.dart';
import '../providers/playlist_providers.dart';
import '../widgets/search_results_list.dart';
import 'playlist_screen.dart';
import 'anime_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlaylist = ref.watch(audioPlaylistProvider);
    final videoPlaylist = ref.watch(videoPlaylistProvider);

    // Count total items across both playlists
    final totalPlaylistItems = audioPlaylist.length + videoPlaylist.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anime Themes Player'),
        actions: [
          // Playlist button with badge showing item count
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.playlist_play),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlaylistScreen(),
                    ),
                  );
                },
                tooltip: 'View Playlists',
              ),
              if (totalPlaylistItems > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$totalPlaylistItems',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search for anime...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  ref.read(searchQueryProvider.notifier).state = value.trim();
                }
              },
            ),
          ),

          // Search results
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final searchResultsAsync = ref.watch(searchResultsProvider);

                return searchResultsAsync.when(
                  data: (results) => SearchResultsList(results: results),
                  loading:
                      () =>
                          const SearchResultsList(results: [], isLoading: true),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AnimeListItem extends StatelessWidget {
  final Anime anime;

  const AnimeListItem({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    // Get the first image if available
    final imageUrl =
        anime.images?.isNotEmpty == true ? anime.images!.first.link : null;
    final hasThemes = anime.animethemes?.isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap:
            hasThemes
                ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnimeDetailScreen(anime: anime),
                    ),
                  );
                }
                : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adjust height based on available width
            final contentHeight = constraints.maxWidth < 300 ? 100.0 : 120.0;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  SizedBox(
                    width: 80, // Reduced from 100 to save space
                    height: contentHeight,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                      errorWidget:
                          (context, url, error) => const Icon(Icons.error),
                    ),
                  )
                else
                  Container(
                    width: 80, // Reduced from 100 to save space
                    height: contentHeight,
                    color: Colors.grey,
                    child: const Icon(Icons.movie, size: 40),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Use min size to avoid extra space
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anime.name,
                          style: const TextStyle(
                            fontSize: 16.0, // Reduced from 18.0
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Format: ${anime.mediaFormat}',
                          style: TextStyle(
                            fontSize: 13.0,
                            color: Colors.grey[600],
                          ), // Reduced from 14.0
                        ),
                        const SizedBox(height: 4.0), // Reduced from 8.0
                        Text(
                          'Themes: ${anime.animethemes?.length ?? 0}',
                          style: const TextStyle(
                            fontSize: 13.0, // Reduced from 14.0
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Chevron icon
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16.0, // Reduced size
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
