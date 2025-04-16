import 'package:freezed_annotation/freezed_annotation.dart';
import 'anime.dart';

part 'anime_response.freezed.dart';
part 'anime_response.g.dart';

@freezed
class AnimeResponse with _$AnimeResponse {
  const factory AnimeResponse({required List<Anime> anime}) = _AnimeResponse;

  factory AnimeResponse.fromJson(Map<String, dynamic> json) =>
      _$AnimeResponseFromJson(json);
}
