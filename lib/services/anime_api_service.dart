import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime_response.dart';
import '../models/anime.dart';
import '../models/anime_theme.dart';
import '../models/anime_theme_entry.dart';
import '../models/video.dart';
import '../models/audio.dart';
import '../models/image.dart';

final animeApiServiceProvider = Provider<AnimeApiService>((ref) {
  return AnimeApiService();
});

class AnimeApiService {
  final http.Client _client;
  final String _baseUrl = 'https://api.animethemes.moe';

  AnimeApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<AnimeResponse> searchAnime(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/anime').replace(
        queryParameters: {
          'q': query,
          'fields[anime]': 'id,name,media_format',
          'include': 'images,animethemes.animethemeentries.videos.audio',
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return _parseAnimeResponse(response.body);
      } else {
        throw Exception('Failed to load anime data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search anime: $e');
    }
  }

  Future<List<Anime>> fetchAnimeList() async {
    try {
      final uri = Uri.parse('$_baseUrl/anime').replace(
        queryParameters: {
          'fields[anime]': 'id,name,media_format',
          'include': 'images',
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return _parseAnimeResponse(response.body).anime;
      } else {
        throw Exception('Failed to load anime list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch anime list: $e');
    }
  }

  Future<Anime> fetchAnimeDetails(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/anime/$id').replace(
        queryParameters: {
          'fields[anime]': 'id,name,media_format',
          'include': 'images,animethemes.animethemeentries.videos.audio',
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['anime'] != null) {
          return _parseAnimeFromJson(jsonData['anime']);
        } else {
          throw Exception('Anime data not found');
        }
      } else {
        throw Exception('Failed to load anime details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch anime details: $e');
    }
  }

  Future<Anime> fetchAnimeDetailsBySlug(String slug) async {
    try {
      final uri = Uri.parse('$_baseUrl/anime/$slug').replace(
        queryParameters: {
          'fields[anime]': 'id,name,media_format',
          'include': 'images,animethemes.animethemeentries.videos.audio',
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['anime'] != null) {
          return _parseAnimeFromJson(jsonData['anime']);
        } else {
          throw Exception('Anime data not found');
        }
      } else {
        throw Exception('Failed to load anime details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch anime details: $e');
    }
  }

  Future<List<AnimeTheme>> fetchAnimeThemes(int animeId) async {
    try {
      final uri = Uri.parse('$_baseUrl/anime/$animeId').replace(
        queryParameters: {
          'include': 'animethemes.animethemeentries.videos.audio',
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['anime'] != null &&
            jsonData['anime']['animethemes'] != null) {
          List<AnimeTheme> themes = [];
          for (var themeJson in jsonData['anime']['animethemes']) {
            themes.add(_parseThemeFromJson(themeJson));
          }
          return themes;
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to load anime themes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch anime themes: $e');
    }
  }

  Future<List<AnimeThemeEntry>> fetchThemeEntries(int themeId) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/animetheme/$themeId',
      ).replace(queryParameters: {'include': 'animethemeentries.videos.audio'});

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['animetheme'] != null &&
            jsonData['animetheme']['animethemeentries'] != null) {
          List<AnimeThemeEntry> entries = [];
          for (var entryJson in jsonData['animetheme']['animethemeentries']) {
            entries.add(_parseEntryFromJson(entryJson));
          }
          return entries;
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to load theme entries: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch theme entries: $e');
    }
  }

  Future<List<Audio>> fetchAnimeAudio(String slug) async {
    try {
      final anime = await fetchAnimeDetailsBySlug(slug);
      List<Audio> audioList = [];

      if (anime.animethemes != null) {
        for (var theme in anime.animethemes!) {
          if (theme.animethemeentries != null) {
            for (var entry in theme.animethemeentries!) {
              if (entry.videos != null) {
                for (var video in entry.videos!) {
                  if (video.audio != null) {
                    audioList.add(video.audio!);
                  }
                }
              }
            }
          }
        }
      }

      return audioList;
    } catch (e) {
      throw Exception('Failed to fetch anime audio: $e');
    }
  }

  Future<List<Video>> fetchAnimeVideo(String slug) async {
    try {
      final anime = await fetchAnimeDetailsBySlug(slug);
      List<Video> videoList = [];

      if (anime.animethemes != null) {
        for (var theme in anime.animethemes!) {
          if (theme.animethemeentries != null) {
            for (var entry in theme.animethemeentries!) {
              if (entry.videos != null) {
                videoList.addAll(entry.videos!);
              }
            }
          }
        }
      }

      return videoList;
    } catch (e) {
      throw Exception('Failed to fetch anime videos: $e');
    }
  }

  AnimeResponse _parseAnimeResponse(String responseBody) {
    final Map<String, dynamic> jsonData = json.decode(responseBody);
    final List<Anime> animes = [];

    if (jsonData['anime'] != null) {
      for (var animeJson in jsonData['anime']) {
        animes.add(_parseAnimeFromJson(animeJson));
      }
    }

    return AnimeResponse(anime: animes);
  }

  Anime _parseAnimeFromJson(Map<String, dynamic> json) {
    final List<AnimeTheme> themes = [];
    if (json['animethemes'] != null) {
      for (var themeJson in json['animethemes']) {
        themes.add(_parseThemeFromJson(themeJson));
      }
    }

    final List<AnimeImage> images = [];
    if (json['images'] != null) {
      for (var imageJson in json['images']) {
        images.add(
          AnimeImage(
            id: imageJson['id'].toString(),
            link: imageJson['link'] ?? '',
            facet: imageJson['facet'],
            path: imageJson['path'],
          ),
        );
      }
    }

    return Anime(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      mediaFormat: json['media_format'] ?? 'Unknown',
      animethemes: themes,
      images: images,
    );
  }

  AnimeTheme _parseThemeFromJson(Map<String, dynamic> json) {
    final List<AnimeThemeEntry> entries = [];
    if (json['animethemeentries'] != null) {
      for (var entryJson in json['animethemeentries']) {
        entries.add(_parseEntryFromJson(entryJson));
      }
    }

    return AnimeTheme(
      id: json['id'].toString(),
      slug: json['slug'] ?? '',
      type: json['type'],
      sequence: json['sequence'],
      animethemeentries: entries,
    );
  }

  AnimeThemeEntry _parseEntryFromJson(Map<String, dynamic> json) {
    final List<Video> videos = [];
    if (json['videos'] != null) {
      for (var videoJson in json['videos']) {
        videos.add(_parseVideoFromJson(videoJson));
      }
    }

    return AnimeThemeEntry(
      id: json['id'].toString(),
      episodes: json['episodes'],
      notes: json['notes'],
      nsfw: json['nsfw'],
      spoiler: json['spoiler'],
      version: json['version'],
      videos: videos,
    );
  }

  Video _parseVideoFromJson(Map<String, dynamic> json) {
    Audio? audio;
    if (json['audio'] != null) {
      audio = Audio(
        id: json['audio']['id'].toString(),
        link: json['audio']['link'] ?? '',
        filename: json['audio']['filename'],
        basename: json['audio']['basename'],
      );
    }

    return Video(
      id: json['id'].toString(),
      link: json['link'] ?? '',
      basename: json['basename'],
      filename: json['filename'],
      lyrics: json['lyrics'],
      nc: json['nc'],
      overlap: json['overlap'],
      path: json['path'],
      resolution: json['resolution'],
      size: json['size'],
      source: json['source'],
      subbed: json['subbed'],
      uncen: json['uncen'],
      tags: json['tags'],
      audio: audio,
    );
  }
}
