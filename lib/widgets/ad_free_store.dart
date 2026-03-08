// lib/ad_free_store.dart
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdFreeStore {
  // ✅ 형님 확인: entitlement id = ad_free
  static const String entitlementId = 'ad_free';

  static final ValueNotifier<bool> isAdFree = ValueNotifier<bool>(false);

  static bool _configured = false;
  static const _spKey = 'is_ad_free_cached';

  static Future<void> init({
    required String revenueCatApiKeyAndroid,
    required String revenueCatApiKeyIOS,
  }) async {
    if (_configured) return;

    // 1) 캐시 먼저 반영(광고 깜빡임 방지)
    final sp = await SharedPreferences.getInstance();
    isAdFree.value = sp.getBool(_spKey) ?? false;

    // 2) configure
    final apiKey = defaultTargetPlatform == TargetPlatform.iOS ? revenueCatApiKeyIOS : revenueCatApiKeyAndroid;

    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;

    // 3) 업데이트 리스너
    Purchases.addCustomerInfoUpdateListener((CustomerInfo info) async {
      await _applyCustomerInfo(info);
    });

    // 4) 최초 1회 동기화
    await refresh();
  }

  // ✅ 이 두 함수만 교체하면 됨: refresh(), _applyCustomerInfo()

  static Future<void> refresh() async {
    if (!_configured) return;

    // 1) 우선 스토어 동기화 시도
    try {
      await Purchases.syncPurchases();
    } catch (_) {
      // sync 실패해도 다음 단계 진행
    }

    // 2) customerInfo 가져오기
    final info = await Purchases.getCustomerInfo();

    // 3) "true → false"로 내려가려는 경우 재검증(한 번 더)
    final wasAdFree = isAdFree.value;
    final nowActive = info.entitlements.active.containsKey(entitlementId);

    if (wasAdFree && !nowActive) {
      // 잠깐 지연 후 다시 동기화/조회 (스토어 반영 지연 방어)
      await Future.delayed(const Duration(milliseconds: 800));
      try {
        await Purchases.syncPurchases();
      } catch (_) {}
      final info2 = await Purchases.getCustomerInfo();
      await _applyCustomerInfo(info2);
      return;
    }

    await _applyCustomerInfo(info);
  }

  static Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final active = info.entitlements.active.containsKey(entitlementId);

    if (isAdFree.value != active) {
      isAdFree.value = active;
    }

    // ✅ 캐시 저장도 active 기준으로만
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_spKey, active);
  }

  static Future<void> buyAdFree() async {
    if (!_configured) throw Exception('AdFreeStore.init() 먼저 호출해야 합니다.');

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;

    if (current == null || current.availablePackages.isEmpty) {
      throw Exception('현재(Current) 오퍼링이 없거나 패키지가 비어있습니다.');
    }

    final pkg = current.monthly ?? current.availablePackages.first;

    final result = await Purchases.purchasePackage(pkg);
    await _applyCustomerInfo(result.customerInfo);

    // ✅ 여기부터 추가: 결제 직후 반영 지연 대응
    // 1) 잠깐 기다렸다가 refresh
    await Future.delayed(const Duration(seconds: 2));
    await refresh();

    // 2) 그래도 false면 restore까지 한 번 시도
    if (!isAdFree.value) {
      await Future.delayed(const Duration(seconds: 2));
      await restore();
    }
  }

  static Future<void> restore() async {
    if (!_configured) throw Exception('AdFreeStore.init() 먼저 호출해야 합니다.');
    final info = await Purchases.restorePurchases();
    await _applyCustomerInfo(info);
  }

}
