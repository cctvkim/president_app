import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../board/board_block_store.dart';
import 'package:url_launcher/url_launcher.dart';

// ✅ 추가: 정기결제(광고 제거)용
import '../widgets/ad_free_store.dart';

class AppSettingsScreen extends StatefulWidget {
  final ValueNotifier<double> fontScale;

  const AppSettingsScreen({
    super.key,
    required this.fontScale,
  });

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late double _value;

  bool _blockLoading = false;
  String? _blockError;
  List<String> _blocked = [];

  // ✅ 정기결제 UI 상태
  bool _subLoading = false;
  String? _subError;

  @override
  void initState() {
    super.initState();
    _value = widget.fontScale.value;
    _loadBlocked();
      // ✅ 설정 화면 열 때마다 최신 구독 상태 반영
    AdFreeStore.refresh();
  }

  Future<void> _save(double v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('font_scale', v);
  }

  Future<void> _loadBlocked() async {
    setState(() {
      _blockLoading = true;
      _blockError = null;
    });

    try {
      final list = await BoardBlockStore.list();
      setState(() {
        _blocked = list;
        _blockLoading = false;
      });
    } catch (e) {
      setState(() {
        _blockError = e.toString();
        _blockLoading = false;
      });
    }
  }

  Future<void> _openContactWebsite() async {
    final uri = Uri.parse('https://cctvkim.github.io/app-hompage/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연락처/정책 페이지를 열 수 없습니다.')),
      );
    }
  }

  Future<void> _unblock(String uuid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('차단 해제'),
        content: Text('차단을 해제할까요?\n$uuid'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('해제')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await BoardBlockStore.unblock(uuid);
      await _loadBlocked();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('차단 해제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해제 실패: $e')),
      );
    }
  }

  // =========================
  // ✅ 정기결제(광고 제거) 기능
  // =========================

Future<void> _buyAdFree() async {
    setState(() {
      _subLoading = true;
      _subError = null;
    });

    try {
      // 1️⃣ 결제 진행
      await AdFreeStore.buyAdFree();

      // 2️⃣ 결제 후 즉시 상태 재조회 (핵심)
      await AdFreeStore.refresh();

      if (!mounted) return;

      final nowAdFree = AdFreeStore.isAdFree.value;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowAdFree ? '광고 제거가 적용되었습니다.' : '결제가 완료되지 않았거나 아직 반영되지 않았습니다. 잠시 후 “구매 복원”을 눌러주세요.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('정기결제 시작 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _subLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _subLoading = true;
      _subError = null;
    });

    try {
      await AdFreeStore.restore();
      await AdFreeStore.refresh();

      if (!mounted) return;

      final nowAdFree = AdFreeStore.isAdFree.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nowAdFree ? '구매 복원 완료: 광고 제거 적용됨' : '구매 복원 완료: 활성 구독이 없습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구매 복원 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _subLoading = false);
    }
  }

  Future<void> _openManageSubscription() async {
    // 구독 해지/변경은 여기서
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구독 관리 페이지를 열 수 없습니다.')),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    // TODO: 너 정책 URL로 교체
    final uri = Uri.parse('https://shift-diary-privacy.s3.ap-northeast-2.amazonaws.com/privacy.html');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('개인정보처리방침 페이지를 열 수 없습니다.')),
      );
    }
  }

  Future<void> _openContactEmail() async {
    final uri = Uri.parse('mailto:cctvkimm1@gmail.com?subject=오늘의%20대통령%20문의');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 열 수 없습니다.')),
      );
    }
  }

  void _showDisclaimerAndSources() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('앱 정보 / 면책 및 출처'),
        content: const SingleChildScrollView(
          child: Text(
            '면책조항\n'
            '- 본 앱은 대한민국 정부 기관을 대표하거나 정부와 공식적으로 제휴한 앱이 아닙니다.\n'
            '- 본 앱은 공개된 자료(RSS/공식 페이지/공식 채널 등)를 모아 보여주는 정보 제공용 앱입니다.\n\n'
            '공식/원본 출처 예시\n'
            '- 정부포털: https://www.korea.kr\n'
            '- 대통령실: https://www.ktv.go.kr\n'
            '문의\n'
            '- 이메일: cctvkimm1@gmail.com\n',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
  }

  Future<void> _openTerms() async {
    // TODO: 너 약관 URL로 교체
    final uri = Uri.parse('https://president-condition.s3.ap-northeast-2.amazonaws.com/condition.html');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이용약관 페이지를 열 수 없습니다.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // 폰트 크기
          // =========================
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('폰트 크기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('현재: ${_value.toStringAsFixed(2)}x', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Slider(
                    value: _value,
                    min: 0.85,
                    max: 1.30,
                    divisions: 9,
                    label: '${_value.toStringAsFixed(2)}x',
                    onChanged: (v) {
                      setState(() => _value = v);
                      widget.fontScale.value = v;
                    },
                    onChangeEnd: (v) => _save(v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          const v = 1.0;
                          setState(() => _value = v);
                          widget.fontScale.value = v;
                          _save(v);
                        },
                        child: const Text('기본(1.0)'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '홈/카드 화면 포함 전체 텍스트에 즉시 적용',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // =========================
          // ✅ 정기결제(광고 제거) 섹션 추가
          // =========================
          ValueListenableBuilder<bool>(
            valueListenable: AdFreeStore.isChecking,
            builder: (context, checking, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: AdFreeStore.isAdFree,
                builder: (context, isAdFree, __) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '광고 제거(정기결제)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          if (checking) ...[
                            Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '구독 상태 확인 중...',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            Row(
                              children: [
                                Icon(isAdFree ? Icons.verified : Icons.info_outline),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isAdFree ? '광고 제거 사용 중' : '현재 광고 표시 중',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_subError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _subError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (_subLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: (checking || isAdFree) ? null : _buyAdFree,
                                        child: const Text('정기결제 시작(광고 제거)'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: checking ? null : _restorePurchases,
                                      child: const Text('구매 복원'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: _openManageSubscription,
                                    child: const Text('구독 관리/해지하기'),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          Text(
                            '정기결제 승인 대기 중이어도 메뉴는 미리 넣어도 됩니다. '
                            '실제 결제는 Play Console에서 상품이 “활성”이 된 뒤 정상 동작합니다.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // =========================
          // 차단 관리
          // =========================
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('차단한 사용자 관리', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                      IconButton(
                        tooltip: '새로고침',
                        onPressed: _blockLoading ? null : _loadBlocked,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_blockLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_blockError != null)
                    Text(_blockError!, style: const TextStyle(color: Colors.red))
                  else if (_blocked.isEmpty)
                    Text('차단한 사용자가 없습니다.', style: Theme.of(context).textTheme.bodySmall)
                  else
                    Column(
                      children: _blocked.map((u) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: TextButton(
                            onPressed: () => _unblock(u),
                            child: const Text('해제'),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '차단하면 해당 작성자의 글/댓글이 목록에서 숨김 처리됩니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('법적 고지', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('개인정보처리방침'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openPrivacyPolicy,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('이용약관'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openTerms,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('문의하기'),
                    subtitle: const Text('cctvkim1@gmail.com'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openContactEmail,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.public),
                    title: const Text('연락처/정책 웹사이트'),
                    subtitle: const Text('연락처 · 면책 · 출처 · 개인정보처리방침'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openContactWebsite,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: const Text('앱 정보 / 면책 및 출처'),
                    trailing: const Icon(Icons.chevron_right),  
                    onTap: _showDisclaimerAndSources,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '앱 사용과 관련된 정책 문서로 이동합니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
