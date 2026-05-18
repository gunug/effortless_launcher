import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'donation_iap.dart';

const _kPurchaseTimeout = Duration(seconds: 90);
const _kBillingSheetGracePeriod = Duration(seconds: 3);

Future<void> showDonationDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _DonationDialog(),
  );
}

class _DonationDialog extends StatefulWidget {
  const _DonationDialog();

  @override
  State<_DonationDialog> createState() => _DonationDialogState();
}

class _DonationDialogState extends State<_DonationDialog>
    with WidgetsBindingObserver {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Timer? _purchaseTimeoutTimer;
  Timer? _billingSheetGraceTimer;

  bool _loading = true;
  bool _purchasing = false;
  bool _billingSheetWasInactive = false;
  String? _errorMessage;
  List<ProductDetails> _products = const [];
  ProductDetails? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) {
        _cancelPendingTimers();
        if (!mounted) return;
        setState(() => _purchasing = false);
        _showSnackBar('Payment failed');
      },
    );
    _loadProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelPendingTimers();
    _subscription?.cancel();
    super.dispose();
  }

  void _cancelPendingTimers() {
    _purchaseTimeoutTimer?.cancel();
    _billingSheetGraceTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_purchasing) return;
    if (state != AppLifecycleState.resumed) {
      _billingSheetWasInactive = true;
      return;
    }
    if (!_billingSheetWasInactive) return;
    _billingSheetGraceTimer?.cancel();
    _billingSheetGraceTimer = Timer(_kBillingSheetGracePeriod, () {
      if (!mounted || !_purchasing) return;
      setState(() => _purchasing = false);
      _showSnackBar('Payment failed');
    });
  }

  Future<void> _loadProducts() async {
    final available = await _iap.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _loading = false;
        _errorMessage = 'In-app purchases are not available on this device.';
      });
      return;
    }

    final response = await _iap.queryProductDetails(kDonationProductIds);
    if (!mounted) return;

    if (response.error != null || response.productDetails.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load donation options. Please try again later.';
      });
      return;
    }

    final sorted = [...response.productDetails]
      ..sort((a, b) => _tierOrder(a.id).compareTo(_tierOrder(b.id)));

    setState(() {
      _loading = false;
      _products = sorted;
      _selected = sorted.firstWhere(
        (p) => p.id == kDonationDefaultProductId,
        orElse: () => sorted.first,
      );
    });
  }

  int _tierOrder(String id) {
    switch (id) {
      case 'donate_small':
        return 0;
      case 'donate_medium':
        return 1;
      case 'donate_large':
        return 2;
      default:
        return 99;
    }
  }

  String _tierLabel(String id) {
    switch (id) {
      case 'donate_small':
        return 'Small';
      case 'donate_medium':
        return 'Medium';
      case 'donate_large':
        return 'Large';
      default:
        return id;
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (!kDonationProductIds.contains(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _cancelPendingTimers();
          if (!mounted) return;
          _showSnackBar(
            'Your support is being processed. Thank you!',
          );
          Navigator.of(context).pop();
          return;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _cancelPendingTimers();
          if (!mounted) return;
          _showSnackBar('Thank you for your support!');
          Navigator.of(context).pop();
          return;
        case PurchaseStatus.error:
          _cancelPendingTimers();
          if (!mounted) return;
          setState(() => _purchasing = false);
          _showSnackBar('Payment failed');
          break;
        case PurchaseStatus.canceled:
          _cancelPendingTimers();
          if (!mounted) return;
          setState(() => _purchasing = false);
          _showSnackBar('Payment canceled');
          break;
      }
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _onDonatePressed() async {
    final selected = _selected;
    if (selected == null || _purchasing) return;

    _billingSheetWasInactive = false;
    setState(() => _purchasing = true);
    _startPurchaseTimeout();

    try {
      final purchaseParam = PurchaseParam(productDetails: selected);
      final started = await _iap.buyConsumable(purchaseParam: purchaseParam);
      if (!started && mounted) {
        _cancelPendingTimers();
        setState(() => _purchasing = false);
        _showSnackBar('Payment failed');
      }
    } catch (_) {
      _cancelPendingTimers();
      if (!mounted) return;
      setState(() => _purchasing = false);
      _showSnackBar('Payment failed');
    }
  }

  void _startPurchaseTimeout() {
    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = Timer(_kPurchaseTimeout, () {
      if (!mounted || !_purchasing) return;
      setState(() => _purchasing = false);
      _showSnackBar('Payment failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Support'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildContent(),
        ),
      ),
      actions: _buildActions(),
    );
  }

  List<Widget> _buildContent() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_errorMessage != null) {
      return [Text(_errorMessage!)];
    }

    return [
      const Text(
        'This is a voluntary donation, not tied to any app feature. '
        'Your support greatly helps development.',
      ),
      const SizedBox(height: 16),
      RadioGroup<ProductDetails>(
        groupValue: _selected,
        onChanged: (v) {
          if (_purchasing || v == null) return;
          setState(() => _selected = v);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in _products)
              RadioListTile<ProductDetails>(
                value: p,
                title: Text('${_tierLabel(p.id)}  ${p.price}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildActions() {
    if (_loading || _errorMessage != null) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _purchasing ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: (_purchasing || _selected == null) ? null : _onDonatePressed,
        child: _purchasing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Donate'),
      ),
    ];
  }
}
