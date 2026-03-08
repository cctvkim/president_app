import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ✅ 추가
import 'ad_free_store.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  static String get _unitId {
    if (Platform.isAndroid) return 'ca-app-pub-4792162071784300/9971789595';
    if (Platform.isIOS) return '';
    return 'ca-app-pub-4792162071784300/9971789595';
  }

  @override
  void initState() {
    super.initState();

    // ✅ 광고 제거 상태면 로드 자체 안 함
    if (AdFreeStore.isAdFree.value) return;

    _ad = BannerAd(
      adUnitId: _unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
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
      builder: (context, isAdFree, _) {
        // ✅ 광고 제거 상태면 완전 숨김
        if (isAdFree) {
          return const SizedBox.shrink();
        }

        if (!_loaded || _ad == null) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: SizedBox(
            height: _ad!.size.height.toDouble(),
            width: double.infinity,
            child: AdWidget(ad: _ad!),
          ),
        );
      },
    );
  }
}
