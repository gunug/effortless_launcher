import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const Set<String> kDonationProductIds = {
  'donate_small',
  'donate_medium',
  'donate_large',
};

const String kDonationDefaultProductId = 'donate_medium';

class DonationPurchaseHandler {
  DonationPurchaseHandler._();

  static final DonationPurchaseHandler instance = DonationPurchaseHandler._();

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  void start() {
    if (_subscription != null) return;
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object err) {
        debugPrint('donation purchase stream error: $err');
      },
    );
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (!kDonationProductIds.contains(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            try {
              await InAppPurchase.instance.completePurchase(purchase);
            } catch (e) {
              debugPrint('completePurchase failed: $e');
            }
          }
          break;
      }
    }
  }
}
