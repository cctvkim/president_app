import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'services/ktv_api.dart';
import 'services/youtube_service.dart';
import 'widgets/ad_free_store.dart'; // 경로가 다르면 맞춰서 수정 (예: widgets/ad_free_store.dart)
import 'screens/home_screen.dart';
import 'screens/president_feed_screen.dart';
import 'screens/president_rss_screen.dart';
import 'screens/president_sns_screen.dart';
import 'screens/youtube_screen.dart';
import 'screens/app_settings_screen.dart';
import 'screens/board_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 광고 초기화
  await MobileAds.instance.initialize();

  // ✅ RevenueCat 초기화 (앱 시작 시 1회, runApp 전에)
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
  const MyApp({super.key, required this.initialFontScale});

  // ✅ KTV 서비스키
  static const ktvServiceKey = '51a07db4a2e56ffaba0e81e32191f5830a3a00e530c6eb421e6e28901cce2f23';

  // ✅ YouTube Data API Key
  static const ytApiKey = 'AIzaSyCbnLIvhOOrdn9EcTcsvbi_ch-0NFOIF0g';

  // ✅ 이재명TV 채널ID
  static const ytChannelId = 'UCNJM6dqu70Qr6VaseiW1Org';

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

    final ytSingle = YoutubeService(
      apiKey: MyApp.ytApiKey,
      channelId: MyApp.ytChannelId,
    );

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
            yt: ytSingle,
            fontScale: fontScale,
          ),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  final KtvApi api;
  final YoutubeService yt;
  final ValueNotifier<double> fontScale;

  const HomeShell({
    super.key,
    required this.api,
    required this.yt,
    required this.fontScale,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(api: widget.api, yt: widget.yt),
      PresidentFeedScreen(api: widget.api),
      const PresidentRssScreen(),
      YoutubeScreen(
        apiKey: MyApp.ytApiKey,
        feeds: const [
          YoutubeFeedSource(
            name: '이재명TV',
            channelId: MyApp.ytChannelId,
          ),
          YoutubeFeedSource(
            name: '매불쇼',
            channelId: 'UCMYhq9OyGI5UEz_NTAoHY7A',
            titleMustContainAny: ['풀버젼', '풀버전'],
          ),
          YoutubeFeedSource(
            name: '김어준의 뉴스공장',
            channelId: 'UCAAvO0ehWox1bbym3rXKBZw',
            titleMustContainAny: ['김어준의 겸손은힘들다', '김어준의 겸손은 힘들다'],
          ),
        ],
      ),
      PresidentSnsScreen(
        youtubeApiKey: MyApp.ytApiKey,
      ),
    ];

    return Scaffold(
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
                  builder: (_) => AppSettingsScreen(fontScale: widget.fontScale),
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
              NavigationDestination(icon: Icon(Icons.home_rounded), label: '홈'),
              NavigationDestination(icon: Icon(Icons.video_library_rounded), label: 'KTV'),
              NavigationDestination(icon: Icon(Icons.feed_rounded), label: 'RSS'),
              NavigationDestination(icon: Icon(Icons.ondemand_video_rounded), label: 'YouTube'),
              NavigationDestination(icon: Icon(Icons.public_rounded), label: 'SNS'),
            ],
          ),
          const BottomBannerAd(),
        ],
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
      adUnitId: 'ca-app-pub-4792162071784300/9971789595', // ✅ 실제 배너 ID
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
        if (adFree) return const SizedBox.shrink(); // ✅ 구독이면 광고 숨김

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
