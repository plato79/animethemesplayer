import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video.dart';
import '../providers/anime_providers.dart';
import '../providers/playlist_providers.dart';
import '../widgets/video_player_widget.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final Video video;
  final bool isPlaylist;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.isPlaylist = false,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    // Update the selected media in the provider from initState
    Future.microtask(() {
      if (!_disposed && mounted && widget.video.link.isNotEmpty) {
        ref.read(selectedMediaProvider.notifier).state = widget.video;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.video.basename ?? 'Video Player',
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Add to playlist button
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: () {
              ref.read(videoPlaylistProvider.notifier).addVideo(widget.video);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added to playlist'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          // Playlist button
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () {
              _showPlaylistBottomSheet(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimeVideoPlayer(
                video: widget.video,
                isPlaylist: widget.isPlaylist,
                fullScreen: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return PlaylistBottomSheet(
              currentVideo: widget.video,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

class PlaylistBottomSheet extends ConsumerWidget {
  final Video currentVideo;
  final ScrollController scrollController;

  const PlaylistBottomSheet({
    super.key,
    required this.currentVideo,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(videoPlaylistProvider);
    final isShuffled = ref.watch(isShuffledProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: isShuffled ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () {
                      ref.read(isShuffledProvider.notifier).state = !isShuffled;
                      ref.read(videoPlaylistProvider.notifier).toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_all, color: Colors.white),
                    onPressed: () {
                      ref.read(videoPlaylistProvider.notifier).clearPlaylist();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.grey),
        Expanded(
          child:
              playlist.isEmpty
                  ? const Center(
                    child: Text(
                      'Playlist is empty',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                  : ListView.builder(
                    controller: scrollController,
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final video = playlist[index];
                      final isCurrentVideo = video.link == currentVideo.link;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        leading: Container(
                          width: 80,
                          height: 48,
                          color: Colors.grey[800],
                          child: Center(
                            child: Icon(
                              isCurrentVideo
                                  ? Icons.play_arrow
                                  : Icons.music_video,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        title: Text(
                          video.basename ?? 'Unknown',
                          style: TextStyle(
                            color: isCurrentVideo ? Colors.blue : Colors.white,
                            fontWeight:
                                isCurrentVideo
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () {
                            ref
                                .read(videoPlaylistProvider.notifier)
                                .removeVideo(video.id);
                          },
                        ),
                        onTap: () {
                          ref.read(selectedMediaProvider.notifier).state =
                              video;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => VideoPlayerScreen(
                                    video: video,
                                    isPlaylist: true,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
