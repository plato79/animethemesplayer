import 'package:freezed_annotation/freezed_annotation.dart';
import 'anime_theme.dart';
import 'image.dart';

part 'anime.freezed.dart';
part 'anime.g.dart';

@freezed
class Anime with _$Anime {
  const factory Anime({
    required String id,
    required String name,
    required String mediaFormat,
    List<AnimeTheme>? animethemes,
    List<AnimeImage>? images,
  }) = _Anime;

  factory Anime.fromJson(Map<String, dynamic> json) => _$AnimeFromJson(json);
}

// Extension to add helper methods to Anime class
extension AnimeHelpers on Anime {
  // Get small cover image for previews
  String? getSmallCoverImage() {
    if (images == null || images!.isEmpty) return null;

    // Try to find small cover
    final smallCover = images!.firstWhere(
      (img) => img.facet == 'Small Cover',
      orElse: () => images!.first,
    );
    return smallCover.link;
  }

  // Get large cover image for playback
  String? getLargeCoverImage() {
    if (images == null || images!.isEmpty) return null;

    // Try to find large cover
    final largeCover = images!.firstWhere(
      (img) => img.facet == 'Large Cover',
      orElse: () => images!.first,
    );
    return largeCover.link;
  }
}
