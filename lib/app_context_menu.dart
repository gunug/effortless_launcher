import 'package:flutter/material.dart';

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
            Text(isProtected ? '삭제 (보호됨)' : '삭제'),
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
            Text('표시 제거'),
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
            Text(isProtected ? '보호 해제' : '보호'),
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
  }
}
