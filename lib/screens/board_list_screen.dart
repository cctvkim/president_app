import 'package:flutter/material.dart';
import '../board/board_api.dart';
import 'board_detail_screen.dart';
import '../board/admin_store.dart';
import '../widgets/ad_banner.dart';

class BoardListScreen extends StatefulWidget {
  const BoardListScreen({super.key});

  @override
  State<BoardListScreen> createState() => _BoardListScreenState();
}

class _BoardListScreenState extends State<BoardListScreen> {
  String _sort = "latest"; // latest | recommended | comments

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _showNoticeOnce();
    _load();
  }


  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await BoardApi.listPosts(sort: _sort, page: 1, size: 20);
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

  String _fmtKST(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y.$m.$d $hh:$mm';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _showNoticeOnce() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시판 이용 안내'),
        content: const Text(
          '• 비방, 욕설, 허위정보 게시 시 삭제될 수 있습니다.\n\n'
          '• 신고 5회 이상 누적되면 자동 블라인드 처리됩니다.\n\n'
          '• 건전한 토론 문화를 지켜주세요.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWriteDialog() async {
    final titleCtl = TextEditingController();
    final contentCtl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('글 작성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('등록')),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: '제목'),
                maxLength: 80,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtl,
                decoration: const InputDecoration(labelText: '내용'),
                minLines: 5,
                maxLines: 10,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    final title = titleCtl.text.trim();
    final content = contentCtl.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    try {
      await BoardApi.createPost(title, content);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () async {
            final ctl = TextEditingController();

            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('관리자 토큰 입력'),
                content: TextField(
                  controller: ctl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'ADMIN TOKEN',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('저장'),
                  ),
                ],
              ),
            );

            if (ok == true) {
              await AdminStore.save(ctl.text.trim());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('관리자 모드 활성화')),
              );
            }
          },
          child: const Text('자유게시판'),
        ),
        actions: [
          IconButton(
            tooltip: '새 글',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openWriteDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('다시 시도')),
                  ],
                )
              : Column(
                  children: [
                    // 🔹 정렬 버튼 영역
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: "latest", label: Text("최신")),
                            ButtonSegment(value: "recommended", label: Text("추천")),
                            ButtonSegment(value: "comments", label: Text("댓글")),
                          ],
                          selected: {_sort},
                          onSelectionChanged: (s) async {
                            setState(() => _sort = s.first);
                            await _load();
                          },
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // 🔹 리스트 영역
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final it = _items[i];
                            final title = (it["title"] ?? "").toString();
                            final createdAt = (it["created_at"] ?? "").toString();
                            final likeCount = it["like_count"] ?? 0;
                            final dislikeCount = it["dislike_count"] ?? 0;
                            final commentCount = it["comment_count"] ?? 0;

                            return ListTile(
                              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                _fmtKST(createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('👍 $likeCount  👎 $dislikeCount', style: Theme.of(context).textTheme.bodySmall),
                                  Text('댓글 $commentCount', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                              onTap: () async {
                                final id = (it["id"] as num).toInt();
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BoardDetailScreen(postId: id),
                                  ),
                                );
                                await _load();
                              },
                              onLongPress: () async {
                                final token = await AdminStore.get();
                                if (token == null || token.trim().isEmpty) return; // 일반 유저는 아무 반응 없음

                                final id = (it["id"] as num).toInt();

                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('관리자 삭제'),
                                    content: Text('게시글 #$id 를 삭제할까요?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                                      ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                                    ],
                                  ),
                                );

                                if (ok != true) return;

                                try {
                                  await BoardApi.adminDeletePost(id, token.trim());
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 완료')));
                                  await _load();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                                }
                              },
                            );

                          },
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}
