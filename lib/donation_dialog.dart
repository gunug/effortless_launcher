import 'package:flutter/material.dart';

enum _DonationTier { small, medium, large }

extension on _DonationTier {
  String get label {
    switch (this) {
      case _DonationTier.small:
        return 'Small';
      case _DonationTier.medium:
        return 'Medium';
      case _DonationTier.large:
        return 'Large';
    }
  }
}

Future<void> showDonationDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  var selected = _DonationTier.medium;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setStateSb) {
          return AlertDialog(
            title: const Text('Support'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This is a voluntary donation, not tied to any app feature. '
                    'Your support greatly helps development.',
                  ),
                  const SizedBox(height: 16),
                  RadioGroup<_DonationTier>(
                    groupValue: selected,
                    onChanged: (v) {
                      if (v != null) setStateSb(() => selected = v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final tier in _DonationTier.values)
                          RadioListTile<_DonationTier>(
                            value: tier,
                            title: Text(tier.label),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Donate'),
              ),
            ],
          );
        },
      );
    },
  );
}
