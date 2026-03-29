import 'package:flutter/material.dart';
import '../board/board_api.dart';
import 'board_detail_screen.dart';
import '../board/admin_store.dart';
import '../widgets/ad_banner.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class BoardListScreen extends StatefulWidget {
  const BoardListScreen({super.key});

  @override
  State<BoardListScreen> createState() => _BoardListScreenState();
}

class _BoardListScreenState extends State<BoardListScreen> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  String _sort = "latest"; // latest | recommended | comments

  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  int _page = 1;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _showNoticeOnce();
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    } else {
      if (_loading || _isLoadingMore || !_hasMore) return;

      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final nextPage = reset ? 1 : (_page + 1);

      final items = await BoardApi.listPosts(
        sort: _sort,
        page: nextPage,
        size: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _items = items;
          _loading = false;
        } else {
          _items = [..._items, ...items];
          _isLoadingMore = false;
        }

        _page = nextPage;

        // 주의: 작성자 차단 필터가 클라이언트 쪽에서 한 번 더 걸리므로
        // length == _pageSize로 끊어버리면 중간에 멈출 수 있어,
        // 일단 "응답이 비면 끝" 기준으로 둔다.
        _hasMore = items.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (reset) {
          _error = e.toString();
          _loading = false;
        } else {
          _isLoadingMore = false;
        }
      });

      if (!reset) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('더보기 실패: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    await _load(reset: false);
  }

  Future<void> _refresh() async {
    await _load(reset: true);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;

    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
    final picker = ImagePicker();
    XFile? pickedImage;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '글 작성',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('등록'),
                      ),
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
                    maxLength: 1000,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final file = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (file == null) return;
                            setSheetState(() {
                              pickedImage = file;
                            });
                          },
                          icon: const Icon(Icons.photo_outlined),
                          label: const Text('사진 선택'),
                        ),
                        if (pickedImage != null)
                          OutlinedButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                pickedImage = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('제거'),
                          ),
                      ],
                    ),
                  ),
                  if (pickedImage != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(pickedImage!.path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;

    final title = titleCtl.text.trim();
    final content = contentCtl.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    try {
      await BoardApi.createPost(
        title,
        content,
        image: pickedImage,
      );
      await _load(reset: true);
      if (!mounted) return;
      await _scrollToTop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    }
  }

  Widget _buildFooter() {
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Center(
          child: FilledButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('더보기'),
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Center(
        child: Text(
          '마지막 글입니다',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        Center(
          child: Text(
            '게시글이 없습니다',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
        SizedBox(height: 120),
      ],
    );
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
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _load(reset: true),
                      child: const Text('다시 시도'),
                    ),
                  ],
                )
              : Column(
                  children: [
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
                            await _load(reset: true);
                            if (!mounted) return;
                            await _scrollToTop();
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: _items.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _items.length + 1,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  if (i == _items.length) {
                                    return _buildFooter();
                                  }

                                  final it = _items[i];
                                  final title = (it["title"] ?? "").toString();
                                  final createdAt = (it["created_at"] ?? "").toString();
                                  final likeCount = it["like_count"] ?? 0;
                                  final dislikeCount = it["dislike_count"] ?? 0;
                                  final commentCount = it["comment_count"] ?? 0;

                                  return ListTile(
                                    title: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _fmtKST(createdAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '👍 $likeCount  👎 $dislikeCount',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        Text(
                                          '댓글 $commentCount',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      final id = (it["id"] as num).toInt();
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => BoardDetailScreen(postId: id),
                                        ),
                                      );

                                      // 상세에서 돌아오면 최신 상태만 다시 불러옴
                                      await _load(reset: true);
                                    },
                                    onLongPress: () async {
                                      final token = await AdminStore.get();
                                      if (token == null || token.trim().isEmpty) return;

                                      final id = (it["id"] as num).toInt();

                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('관리자 삭제'),
                                          content: Text('게시글 #$id 를 삭제할까요?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('취소'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('삭제'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (ok != true) return;

                                      try {
                                        await BoardApi.adminDeletePost(id, token.trim());
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('삭제 완료')),
                                        );
                                        await _load(reset: true);
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('삭제 실패: $e')),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.small(
              heroTag: 'board_scroll_top',
              onPressed: _scrollToTop,
              child: const Icon(Icons.vertical_align_top),
            ),
      bottomNavigationBar: const AdBanner(),
    );
  }
}
