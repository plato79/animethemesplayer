import 'package:freezed_annotation/freezed_annotation.dart';
import 'audio.dart';

part 'video.freezed.dart';
part 'video.g.dart';

@freezed
class Video with _$Video {
  const factory Video({
    required String id,
    required String link,
    String? basename,
    String? filename,
    bool? lyrics,
    bool? nc, // No credits
    String? overlap,
    String? path,
    int? resolution,
    int? size,
    String? source,
    bool? subbed,
    bool? uncen,
    String? tags,
    Audio? audio,
  }) = _Video;

  factory Video.fromJson(Map<String, dynamic> json) => _$VideoFromJson(json);
}
