import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../controllers/auth_controller.dart';
import 'firestore_user_service.dart';

class SubscriptionService extends GetxService {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  final RxList<ProductDetails> products = <ProductDetails>[].obs;
  final RxList<PurchaseDetails> purchases = <PurchaseDetails>[].obs;
  final RxBool isAvailable = false.obs;
  final RxBool isLoading = false.obs;

  // 🛡️ التبعيات المطلوبة للإتمام
  AuthController get _auth => Get.find<AuthController>();
  FirestoreUserService get _firestoreUser => Get.find<FirestoreUserService>();

  // Define your product IDs here (match Google Play Console / App Store Connect)
  static const String _monthlySubscriptionId = 'smart_content_creator_monthly';
  static const Set<String> _kIds = {_monthlySubscriptionId};

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }

  Future<void> _initialize() async {
    isAvailable.value = await _iap.isAvailable();
    if (isAvailable.value) {
      final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _onPurchaseUpdates,
        onDone: () {
          _subscription.cancel();
        },
        onError: (error) {
          debugPrint('IAP Error: $error');
        },
      );
      await _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    isLoading.value = true;
    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_kIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }
      products.assignAll(response.productDetails);
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> buySubscription() async {
    if (products.isEmpty) {
      Get.snackbar('خطأ', 'المنتجات غير متوفرة حالياً');
      return;
    }

    // Assuming single product for now
    final ProductDetails productDetails = products.first;
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      Get.snackbar('خطأ', 'فشلت عملية الشراء: $e');
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      Get.snackbar('خطأ', 'فشلت استعادة المشتريات: $e');
    }
  }

  Future<void> _onPurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          Get.snackbar('خطأ', 'حدث خطأ في الشراء');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            _deliverProduct(purchaseDetails);
          } else {
            _handleInvalidPurchase(purchaseDetails);
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // 🛡️ منطق التحقق من المشتريات (Backend Verification)
    // في بيئة الإنتاج، يجب إرسال purchaseDetails.verificationData إلى سيرفر خاص
    // ليقوم بالتحقق من صحة الفاتورة مع Google Play / App Store.

    if (kDebugMode) {
      debugPrint("🔍 Verifying Purchase: ${purchaseDetails.productID}");
    }

    // محاكاة استجابة السيرفر بنجاح
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  void _deliverProduct(PurchaseDetails purchaseDetails) async {
    // 🔓 تفعيل الميزات والاشتراك
    Get.snackbar('تم بنجاح', 'تم تفعيل الاشتراك بنجاح! 🎉 استمتع بميزات Pro.');
    purchases.add(purchaseDetails);

    // 🔄 تحديث حالة المستخدم في Firestore
    final uid = _auth.firebaseUid;
    if (uid != null) {
      await _firestoreUser.updateUserProfile(
        uid: uid,
        data: {
          'isPremium': true,
          'subscriptionStatus': 'active',
          'subscriptionExpiry':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        },
      );
      if (kDebugMode) {
        debugPrint("✅ User status updated to Premium in Firestore");
      }
    }
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    Get.snackbar('خطأ', 'عملية الشراء غير صالحة');
  }
}
