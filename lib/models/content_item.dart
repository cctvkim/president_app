enum SourceType { cardNews, video, rss }


class ContentItem {
  final String id; // cardId or contentId
  final SourceType source;
  final String title;
  final String description; // content/description (정제된 텍스트)
  final DateTime publishedAt;
  final String thumbnailUrl; // imgUrl
  final String linkUrl; // linkUrl
  final int? viewCnt;
  final String? programName; // video only
  final String? categoryName; // video only

  ContentItem({
    required this.id,
    required this.source,
    required this.title,
    required this.description,
    required this.publishedAt,
    required this.thumbnailUrl,
    required this.linkUrl,
    this.viewCnt,
    this.programName,
    this.categoryName,
  });

  String get uniqueKey => '${source.name}::$id';
}
