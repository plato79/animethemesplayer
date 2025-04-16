import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anime_themes_media_player/screens/audio_player_screen.dart';
import 'package:anime_themes_media_player/screens/video_player_screen.dart';
import '../providers/anime_providers.dart';
import '../providers/playlist_providers.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key}) : super();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPlaylist = ref.watch(audioPlaylistProvider);
    final videoPlaylist = ref.watch(videoPlaylistProvider);
    final isShuffled = ref.watch(isShuffledProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Playlists'),
          actions: [
            // Toggle shuffle button
            IconButton(
              icon: Icon(
                isShuffled ? Icons.shuffle_on : Icons.shuffle,
                color:
                    isShuffled ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: () {
                final newValue = !isShuffled;
                ref.read(isShuffledProvider.notifier).state = newValue;

                // Apply shuffle to both playlists
                if (audioPlaylist.isNotEmpty) {
                  ref.read(audioPlaylistProvider.notifier).toggleShuffle();
                }
                if (videoPlaylist.isNotEmpty) {
                  ref.read(videoPlaylistProvider.notifier).toggleShuffle();
                }
              },
              tooltip: 'Toggle Shuffle Mode',
            ),
            // Clear all playlists button
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Clear Playlists'),
                        content: const Text(
                          'Are you sure you want to clear all playlists?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(audioPlaylistProvider.notifier)
                                  .clearPlaylist();
                              ref
                                  .read(videoPlaylistProvider.notifier)
                                  .clearPlaylist();
                              Navigator.pop(context);
                            },
                            child: const Text('CLEAR'),
                          ),
                        ],
                      ),
                );
              },
              tooltip: 'Clear All Playlists',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Audio', icon: Icon(Icons.audiotrack)),
              Tab(text: 'Video', icon: Icon(Icons.videocam)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Audio Playlist Tab
            _buildAudioPlaylist(ref, context),

            // Video Playlist Tab
            _buildVideoPlaylist(),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlaylist(WidgetRef ref, BuildContext context) {
    final audioPlaylist = ref.watch(audioPlaylistProvider);

    if (audioPlaylist.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Your audio playlist is empty',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Add audio from anime themes to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show the audio playlist items
    return ListView.builder(
      itemCount: audioPlaylist.length,
      itemBuilder: (context, index) {
        final audio = audioPlaylist[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.8),
            backgroundImage:
                audio.animeImageUrl != null
                    ? NetworkImage(audio.animeImageUrl!)
                    : null,
            child:
                audio.animeImageUrl == null
                    ? const Icon(Icons.music_note, color: Colors.white)
                    : null,
          ),
          title: Text(
            audio.basename ?? 'Audio ${index + 1}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(audio.filename ?? 'Audio Track'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  // Set playback mode to playlist
                  ref.read(playbackModeProvider.notifier).state =
                      PlaybackMode.playlist;

                  // Update current audio in playlist
                  ref
                      .read(audioPlaylistProvider.notifier)
                      .setCurrentAudio(audio);

                  // Launch the dedicated audio player screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => AudioPlayerScreen(
                            initialAudio: audio,
                            isPlaylist: true,
                          ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  ref
                      .read(audioPlaylistProvider.notifier)
                      .removeAudio(audio.id);
                },
              ),
            ],
          ),
          onTap: () {
            // Set playback mode to playlist
            ref.read(playbackModeProvider.notifier).state =
                PlaybackMode.playlist;

            // Update current audio in playlist
            ref.read(audioPlaylistProvider.notifier).setCurrentAudio(audio);

            // Launch the dedicated audio player screen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => AudioPlayerScreen(
                      initialAudio: audio,
                      isPlaylist: true,
                    ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoPlaylist() {
    return Consumer(
      builder: (context, ref, child) {
        final playlist = ref.watch(videoPlaylistProvider);

        if (playlist.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Your video playlist is empty',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Add videos from anime themes to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: playlist.length,
          itemBuilder: (context, index) {
            final item = playlist[index];
            return ListTile(
              leading: Container(
                width: 60,
                height: 60,
                color: Colors.black54,
                child: const Icon(Icons.movie_outlined, color: Colors.white70),
              ),
              title: Text(item.basename ?? 'Unknown Title'),
              subtitle: Text(item.filename ?? 'Unknown Source'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play button
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      // Set selected media and navigate to video player
                      ref.read(selectedMediaProvider.notifier).state = item;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => VideoPlayerScreen(
                                video: item,
                                isPlaylist: true,
                              ),
                        ),
                      );
                    },
                  ),
                  // Remove button
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      ref
                          .read(videoPlaylistProvider.notifier)
                          .removeFromPlaylist(item.id);
                    },
                  ),
                ],
              ),
              onTap: () {
                // Set selected media and navigate to video player
                ref.read(selectedMediaProvider.notifier).state = item;
                ref.read(playbackModeProvider.notifier).state =
                    PlaybackMode.playlist;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            VideoPlayerScreen(video: item, isPlaylist: true),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
