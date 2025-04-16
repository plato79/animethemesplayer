import 'package:freezed_annotation/freezed_annotation.dart';
import 'video.dart';

part 'anime_theme_entry.freezed.dart';
part 'anime_theme_entry.g.dart';

@freezed
class AnimeThemeEntry with _$AnimeThemeEntry {
  const factory AnimeThemeEntry({
    required String id,
    String? episodes,
    String? notes,
    bool? nsfw,
    bool? spoiler,
    int? version,
    List<Video>? videos,
  }) = _AnimeThemeEntry;

  factory AnimeThemeEntry.fromJson(Map<String, dynamic> json) =>
      _$AnimeThemeEntryFromJson(json);
}
