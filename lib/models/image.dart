import 'package:freezed_annotation/freezed_annotation.dart';

part 'image.freezed.dart';
part 'image.g.dart';

@freezed
class AnimeImage with _$AnimeImage {
  const factory AnimeImage({
    required String id,
    required String link,
    String? facet,
    String? path,
  }) = _AnimeImage;

  factory AnimeImage.fromJson(Map<String, dynamic> json) =>
      _$AnimeImageFromJson(json);
}
