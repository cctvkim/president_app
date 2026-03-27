import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class AdFreeStore {
  static const String entitlementId = 'ad_free';

  static final ValueNotifier<bool> isAdFree = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isChecking = ValueNotifier<bool>(true);

  static bool _configured = false;

  static Future<void> init({
    required String revenueCatApiKeyAndroid,
    required String revenueCatApiKeyIOS,
  }) async {
    if (_configured) return;

    // 진단 단계에서는 캐시 사용하지 않음
    isAdFree.value = false;
    isChecking.value = true;

    final apiKey = defaultTargetPlatform == TargetPlatform.iOS ? revenueCatApiKeyIOS : revenueCatApiKeyAndroid;

    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;

    Purchases.addCustomerInfoUpdateListener((CustomerInfo info) async {
      _logCustomerInfo('listener', info);
      await _applyCustomerInfo(info);
    });

    await refresh();
  }

  static Future<void> refresh() async {
    if (!_configured) return;

    isChecking.value = true;

    try {
      final info = await Purchases.getCustomerInfo();
      _logCustomerInfo('refresh', info);
      await _applyCustomerInfo(info);
    } catch (e) {
      debugPrint('[RC] refresh error: $e');
    } finally {
      isChecking.value = false;
    }
  }

  static Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final active = info.entitlements.active[entitlementId]?.isActive == true;
    debugPrint('[RC] _applyCustomerInfo active=$active');

    if (isAdFree.value != active) {
      isAdFree.value = active;
    }
  }

  static Future<void> buyAdFree() async {
    if (!_configured) {
      throw Exception('AdFreeStore.init() 먼저 호출해야 합니다.');
    }

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;

    debugPrint('[RC] current offering=${current?.identifier}');
    debugPrint('[RC] packages=${current?.availablePackages.map((e) => e.identifier).toList()}');

    if (current == null || current.availablePackages.isEmpty) {
      throw Exception('현재(Current) 오퍼링이 없거나 패키지가 비어있습니다.');
    }

    final pkg = current.monthly ?? current.availablePackages.first;
    debugPrint('[RC] purchase package=${pkg.identifier} product=${pkg.storeProduct.identifier}');

    final result = await Purchases.purchasePackage(pkg);
    _logCustomerInfo('purchase result', result.customerInfo);
    await _applyCustomerInfo(result.customerInfo);

    await Future.delayed(const Duration(seconds: 2));
    await refresh();
  }

  static Future<void> restore() async {
    if (!_configured) {
      throw Exception('AdFreeStore.init() 먼저 호출해야 합니다.');
    }

    final info = await Purchases.restorePurchases();
    _logCustomerInfo('restore', info);
    await _applyCustomerInfo(info);
  }

  static void _logCustomerInfo(String tag, CustomerInfo info) {
    final activeKeys = info.entitlements.active.keys.toList();
    final allKeys = info.entitlements.all.keys.toList();
    final adFreeActive = info.entitlements.active[entitlementId]?.isActive == true;
    final adFreeAll = info.entitlements.all[entitlementId]?.isActive;

    debugPrint('[RC][$tag] activeKeys=$activeKeys');
    debugPrint('[RC][$tag] allKeys=$allKeys');
    debugPrint('[RC][$tag] $entitlementId active(in active)=$adFreeActive');
    debugPrint('[RC][$tag] $entitlementId active(in all)=$adFreeAll');
    debugPrint('[RC][$tag] originalAppUserId=${info.originalAppUserId}');
  }
}
