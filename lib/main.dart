import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'services/ktv_api.dart';
import 'widgets/ad_free_store.dart';
import 'screens/home_screen.dart';
import 'screens/president_feed_screen.dart';
import 'screens/president_rss_screen.dart';
import 'screens/president_sns_screen.dart';
import 'screens/youtube_server_screen.dart';
import 'screens/app_settings_screen.dart';
import 'screens/board_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  await AdFreeStore.init(
    revenueCatApiKeyAndroid: 'goog_zlwMNlQkSMgBnlnkpLanOpLnSLR',
    revenueCatApiKeyIOS: '',
  );

  final sp = await SharedPreferences.getInstance();
  final savedScale = sp.getDouble('font_scale') ?? 1.0;

  runApp(MyApp(initialFontScale: savedScale));
}

class MyApp extends StatefulWidget {
  final double initialFontScale;

  const MyApp({
    super.key,
    required this.initialFontScale,
  });

  static const ktvServiceKey = '51a07db4a2e56ffaba0e81e32191f5830a3a00e530c6eb421e6e28901cce2f23';

  static const ytChannelId = 'UCNJM6dqu70Qr6VaseiW1Org';
  static const ytServerBaseUrl = 'http://13.209.167.188:8002';

  // ✅ 여기만 형님이 방금 만든 네이티브 광고 고급형 ID로 교체
  static const exitNativeAdUnitIdAndroid = '여기에_안드로이드_네이티브_광고_ID';
  static const exitNativeAdUnitIdIOS = '';

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ValueNotifier<double> fontScale = ValueNotifier<double>(widget.initialFontScale);

  @override
  void dispose() {
    fontScale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ktvApi = KtvApi(MyApp.ktvServiceKey);

    return ValueListenableBuilder<double>(
      valueListenable: fontScale,
      builder: (context, scale, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(scale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeShell(
            api: ktvApi,
            fontScale: fontScale,
          ),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  final KtvApi api;
  final ValueNotifier<double> fontScale;

  const HomeShell({
    super.key,
    required this.api,
    required this.fontScale,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _exitDialogShowing = false;

  Future<void> _showExitDialog() async {
    // 이미 광고 제거 상태면 종료창 없이 바로 종료
    try {
      await AdFreeStore.refresh(); // 형님 코드에 이미 있으면 사용
    } catch (_) {}

    if (AdFreeStore.isAdFree.value) {
      if (Platform.isAndroid) {
        await SystemNavigator.pop();
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }

    if (_exitDialogShowing) return;
    _exitDialogShowing = true;

    final shouldExit = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (_) => const ExitAdDialog(),
        ) ??
        false;

    _exitDialogShowing = false;

    if (!mounted) return;

    if (shouldExit) {
      if (Platform.isAndroid) {
        await SystemNavigator.pop();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<bool> _onWillPop() async {
    await _showExitDialog();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        api: widget.api,
        youtubeServerBaseUrl: MyApp.ytServerBaseUrl,
        youtubeChannelId: MyApp.ytChannelId,
      ),
      PresidentFeedScreen(api: widget.api),
      const PresidentRssScreen(),
      YoutubeServerScreen(
        baseUrl: MyApp.ytServerBaseUrl,
      ),
      PresidentSnsScreen(
        youtubeServerBaseUrl: MyApp.ytServerBaseUrl,
      ),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: '시사게시판',
              icon: const Icon(Icons.forum_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BoardListScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppSettingsScreen(
                      fontScale: widget.fontScale,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavigationBar(
              height: 64,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  label: '홈',
                ),
                NavigationDestination(
                  icon: Icon(Icons.video_library_rounded),
                  label: 'KTV',
                ),
                NavigationDestination(
                  icon: Icon(Icons.feed_rounded),
                  label: 'RSS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.ondemand_video_rounded),
                  label: 'YouTube',
                ),
                NavigationDestination(
                  icon: Icon(Icons.public_rounded),
                  label: 'SNS',
                ),
              ],
            ),
            const BottomBannerAd(),
          ],
        ),
      ),
    );
  }
}

class BottomBannerAd extends StatefulWidget {
  const BottomBannerAd({super.key});

  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    _ad = BannerAd(
      adUnitId: 'ca-app-pub-4792162071784300/9971789595',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          setState(() => _loaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdFreeStore.isAdFree,
      builder: (context, adFree, _) {
        if (adFree) return const SizedBox.shrink();

        final ad = _ad;
        if (!_loaded || ad == null) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }
}

class ExitAdDialog extends StatefulWidget {
  const ExitAdDialog({super.key});

  @override
  State<ExitAdDialog> createState() => _ExitAdDialogState();
}

class _ExitAdDialogState extends State<ExitAdDialog> {
  NativeAd? _nativeAd;
  bool _loaded = false;
  bool _loadStarted = false;
  bool _failed = false;
  bool _timedOut = false;
  String _message = '';

  String get _adUnitId {
    if (Platform.isAndroid) {
      return MyApp.exitNativeAdUnitIdAndroid;
    }
    return MyApp.exitNativeAdUnitIdIOS;
  }

  @override
  void initState() {
    super.initState();
    _tryLoadAd();
  }

  void _tryLoadAd() {
    if (_loadStarted) return;
    if (AdFreeStore.isAdFree.value) return;
    if (_adUnitId.trim().isEmpty) return;

    _loadStarted = true;

    // 4초 안 뜨면 로딩 중단
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (!_loaded && !_failed) {
        setState(() {
          _timedOut = true;
          _message = '광고를 불러오지 못했습니다.';
        });
      }
    });

    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _loaded = true;
            _failed = false;
            _timedOut = false;
            _message = '';
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Exit native ad failed: $error');
          ad.dispose();
          _nativeAd = null;

          if (!mounted) return;
          setState(() {
            _loaded = false;
            _failed = true;
            _timedOut = false;
            _message = '광고를 표시할 수 없습니다.';
          });
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        cornerRadius: 16,
        mainBackgroundColor: Colors.white,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF111111),
          style: NativeTemplateFontStyle.bold,
          size: 15,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF222222),
          style: NativeTemplateFontStyle.bold,
          size: 16,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF666666),
          style: NativeTemplateFontStyle.normal,
          size: 13,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF888888),
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  Widget _buildAdBox(bool adFree) {
    if (adFree) return const SizedBox.shrink();
    if (_adUnitId.trim().isEmpty) return const SizedBox.shrink();

    if (_loaded && _nativeAd != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '광고',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF335CFF),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 320,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6E6E6)),
            ),
            clipBehavior: Clip.antiAlias,
            child: AdWidget(ad: _nativeAd!),
          ),
        ],
      );
    }

    // 실패 또는 타임아웃이면 로딩 말고 빈 박스만 보여줌
    if (_failed || _timedOut) {
      return Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        alignment: Alignment.center,
        child: Text(
          _message.isEmpty ? '광고를 불러오지 못했습니다.' : _message,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdFreeStore.isAdFree,
      builder: (context, adFree, _) {
        if (adFree) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(true);
          });
          return const SizedBox.shrink();
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '앱을 종료할까요?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _buildAdBox(adFree),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(fontSize: 17),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '앱 종료',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
