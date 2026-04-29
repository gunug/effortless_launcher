import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showAppContextMenu({
  required BuildContext context,
  required Offset position,
  required String packageName,
  required bool isProtected,
  required Future<void> Function(String) onDelete,
  required Future<void> Function(String) onRemoveFromRecent,
  required Future<void> Function(String) onToggleProtect,
}) async {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final result = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(10, 10),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem<String>(
        value: 'delete',
        enabled: !isProtected,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, size: 18),
            const SizedBox(width: 12),
            Text(isProtected ? 'Delete (Protected)' : 'Delete'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'remove',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 18),
            SizedBox(width: 12),
            Text('Hide'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'protect',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isProtected ? Icons.lock_open_outlined : Icons.lock_outline,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(isProtected ? 'Unprotect' : 'Protect'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'info',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 12),
            Text('App Info'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'store',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shop_outlined, size: 18),
            SizedBox(width: 12),
            Text('Play Store'),
          ],
        ),
      ),
    ],
  );
  if (result == null) return;
  switch (result) {
    case 'delete':
      await onDelete(packageName);
      break;
    case 'remove':
      await onRemoveFromRecent(packageName);
      break;
    case 'protect':
      await onToggleProtect(packageName);
      break;
    case 'info':
      InstalledApps.openSettings(packageName);
      break;
    case 'store':
      await _openPlayStore(packageName);
      break;
  }
}

Future<void> _openPlayStore(String packageName) async {
  final marketUri = Uri.parse('market://details?id=$packageName');
  if (await canLaunchUrl(marketUri)) {
    await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    return;
  }
  final webUri =
      Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
  await launchUrl(webUri, mode: LaunchMode.externalApplication);
}
