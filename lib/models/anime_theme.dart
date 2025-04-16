import 'package:freezed_annotation/freezed_annotation.dart';
import 'anime_theme_entry.dart';

part 'anime_theme.freezed.dart';
part 'anime_theme.g.dart';

@freezed
class AnimeTheme with _$AnimeTheme {
  const factory AnimeTheme({
    required String id,
    required String slug,
    String? type,
    int? sequence,
    List<AnimeThemeEntry>? animethemeentries,
  }) = _AnimeTheme;

  factory AnimeTheme.fromJson(Map<String, dynamic> json) =>
      _$AnimeThemeFromJson(json);
}
