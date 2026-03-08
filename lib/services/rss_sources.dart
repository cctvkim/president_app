class RssSource {
  final String id;
  final String title;
  final String url;

  const RssSource({
    required this.id,
    required this.title,
    required this.url,
  });
}

/// 🔒 여기만 수정하면 RSS가 늘어난다
const List<RssSource> kPresidentRssSources = [
  RssSource(
    id: 'president',
    title: '청와대 브리핑',
    url: 'https://www.korea.kr/rss/president.xml',
  ),
  RssSource(
    id: 'policy',
    title: '정책 뉴스',
    url: 'https://www.korea.kr/rss/policy.xml',
  ),
  RssSource(
    id: 'cabinet',
    title: '국무회의 브리핑',
    url: 'https://www.korea.kr/rss/cabinet.xml',
  ),
  RssSource(
    id: 'speech',
    title: '대통령 연설·발언',
    url: 'https://www.korea.kr/rss/speech.xml',
  ),
];
