import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_item.dart';
import '../services/korea_kr_rss.dart';
import '../services/rss_sources.dart';

class PresidentRssScreen extends StatelessWidget {
  const PresidentRssScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: kPresidentRssSources.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RSS'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final src in kPresidentRssSources) Tab(text: src.title),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final src in kPresidentRssSources) _RssListTab(source: src),
          ],
        ),
      ),
    );
  }
}

class _RssListTab extends StatefulWidget {
  final RssSource source;
  const _RssListTab({required this.source});

  @override
  State<_RssListTab> createState() => _RssListTabState();
}

class _RssListTabState extends State<_RssListTab> {
  late final KoreaKrRssService _svc;

  bool _loading = true;
  String? _error;
  List<ContentItem> _items = [];

  @override
  void initState() {
    super.initState();
    _svc = KoreaKrRssService(feedUrl: widget.source.url);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _svc.fetch(limit: 50);
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  String _dateLabel(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _hostOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return '';
    return u.host;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('에러', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final it = _items[i];
          final date = _dateLabel(it.publishedAt);
          final host = _hostOf(it.linkUrl);

          return Card(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: ListTile(
              onTap: () => _open(it.linkUrl),
              title: Text(
                it.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(date, style: const TextStyle(fontSize: 12)),
                    ),
                  if (host.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '출처: $host',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.open_in_new),
            ),
          );
        },
      ),
    );
  }
}
