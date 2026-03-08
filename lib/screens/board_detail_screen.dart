import 'package:flutter/material.dart';
import '../board/board_api.dart';
import '../board/board_block_store.dart';

class BoardDetailScreen extends StatefulWidget {
  final int postId;
  const BoardDetailScreen({super.key, required this.postId});

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final post = await BoardApi.getPost(widget.postId);
      final comments = await BoardApi.listComments(widget.postId, sort: "latest");

      setState(() {
        _post = post;
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleBlockAuthor() async {
    final authorUuid = (_post?["author_uuid"] ?? "").toString();
    if (authorUuid.isEmpty) return;

    final blocked = await BoardBlockStore.isBlocked(authorUuid);

    if (blocked) {
      await BoardBlockStore.unblock(authorUuid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('작성자 차단 해제')));
    } else {
      await BoardBlockStore.block(authorUuid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('작성자 차단됨')));
    }

    setState(() {});
  }

  String? _extractAuthorUuid(Map<String, dynamic>? it) {
    if (it == null) return null;
    final v = (it["author_uuid"] ?? it["device_uuid"] ?? it["writer_uuid"] ?? it["user_uuid"])?.toString();
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  Future<void> _writeComment({int? parentId}) async {
    final ctl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(parentId == null ? '댓글 작성' : '대댓글 작성'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(hintText: '내용'),
          maxLines: 5,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('등록')),
        ],
      ),
    );

    if (ok != true) return;
    final text = ctl.text.trim();
    if (text.isEmpty) return;

    try {
      await BoardApi.createComment(widget.postId, text, parentId: parentId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    }
  }

  Future<String?> _askReportReason() async {
    final ctl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신고 사유'),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '욕설, 비방, 허위정보 등',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('신고')),
        ],
      ),
    );

    if (ok != true) return null;
    final text = ctl.text.trim();
    return text.isEmpty ? '기타' : text;
  }

  Future<void> _reportPost() async {
    final reason = await _askReportReason();
    if (reason == null) return;

    try {
      final r = await BoardApi.reportPost(widget.postId, reason);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고 접수됨 (누적 ${r["report_count"]})')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신고 실패: $e')));
    }
  }

  Future<void> _reportComment(int commentId) async {
    final reason = await _askReportReason();
    if (reason == null) return;

    try {
      await BoardApi.reportComment(commentId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고 접수됨')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신고 실패: $e')));
    }
  }

  Future<void> _blockAuthorFromItem(Map<String, dynamic> item) async {
    final uuid = _extractAuthorUuid(item);
    if (uuid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작성자 정보가 없어 차단할 수 없습니다.')),
      );
      return;
    }

    final already = await BoardBlockStore.isBlocked(uuid);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(already ? '작성자 차단 해제' : '작성자 차단'),
        content: Text(already ? '이 작성자의 글/댓글 숨김을 해제합니다.' : '이 작성자의 글/댓글을 숨깁니다.\n(설정에서 해제 가능)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(already ? '해제' : '차단'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    if (already) {
      await BoardBlockStore.unblock(uuid);
    } else {
      await BoardBlockStore.block(uuid);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(already ? '차단 해제되었습니다.' : '차단되었습니다.')),
    );

    setState(() {}); // 버튼 색/아이콘 즉시 반영용
    await _load();
  }


  Widget _moreMenuForPost() {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == "report") {
          await _reportPost();
        } else if (v == "block") {
          final post = _post;
          if (post != null) await _blockAuthorFromItem(post);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: "report", child: Text("신고하기")),
        PopupMenuItem(value: "block", child: Text("작성자 차단")),
      ],
    );
  }

  Widget _moreMenuForComment(Map<String, dynamic> item, int commentId) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == "report") {
          await _reportComment(commentId);
        } else if (v == "block") {
          await _blockAuthorFromItem(item);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: "report", child: Text("신고하기")),
        PopupMenuItem(value: "block", child: Text("작성자 차단")),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final postUuid = _extractAuthorUuid(_post);


    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          _moreMenuForPost(),
          // ✅ 상단 '새 댓글' 버튼 제거 (댓글 섹션에서 작성하게 함)
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        (post?["title"] ?? "").toString(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text((post?["content"] ?? "").toString()),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.thumb_up_alt_outlined),
                            onPressed: () async {
                              await BoardApi.reactPost(widget.postId, 1);
                              await _load();
                            },
                          ),
                          Text('${_post?["like_count"] ?? 0}'),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.thumb_down_alt_outlined),
                            onPressed: () async {
                              await BoardApi.reactPost(widget.postId, -1);
                              await _load();
                            },
                          ),
                          Text('${_post?["dislike_count"] ?? 0}'),
                          const SizedBox(width: 12),
                          Text('댓글 ${_post?["comment_count"] ?? 0}'),
                          IconButton(
                            icon: FutureBuilder<bool>(
                              future: postUuid == null ? Future.value(false) : BoardBlockStore.isBlocked(postUuid),
                              builder: (context, snapshot) {
                                final blocked = snapshot.data ?? false;
                                return Icon(
                                  blocked ? Icons.block : Icons.block_outlined,
                                  color: blocked ? Colors.red : null,
                                );
                              },
                            ),
                            onPressed: postUuid == null
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('작성자 정보가 없어 차단할 수 없습니다.')),
                                    );
                                  }
                                : () async {
                                    final post = _post;
                                    if (post != null) await _blockAuthorFromItem(post);
                                  },
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 6),

                      // ✅ 댓글 헤더 + 작성 버튼(오른쪽)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('댓글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          TextButton.icon(
                            onPressed: () => _writeComment(),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('작성'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('댓글이 없습니다')),
                        )
                      else
                        ..._comments.map((c) {
                          final replies = (c["replies"] as List?)?.cast<dynamic>() ?? [];
                          final cid = (c["id"] as num).toInt();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text((c["content"] ?? "").toString()),
                                  subtitle: Text((c["created_at"] ?? "").toString()),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                                        onPressed: () async {
                                          await BoardApi.reactComment(cid);
                                          await _load();
                                        },
                                      ),
                                      Text('${c["like_count"] ?? 0}'),
                                      _moreMenuForComment(c, cid),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () => _writeComment(parentId: cid),
                                    child: const Text('답글 달기'),
                                  ),
                                ),
                                if (replies.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Column(
                                      children: replies.map((r) {
                                        final rid = (r["id"] as num).toInt();
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
                                          title: Text((r["content"] ?? "").toString()),
                                          subtitle: Text((r["created_at"] ?? "").toString()),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                                                onPressed: () async {
                                                  try {
                                                    await BoardApi.reactComment(rid);
                                                    await _load();
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('댓글 좋아요 실패: $e')),
                                                    );
                                                  }
                                                },
                                              ),
                                              Text('${r["like_count"] ?? 0}'),
                                              _moreMenuForComment(r.cast<String, dynamic>(), rid),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
