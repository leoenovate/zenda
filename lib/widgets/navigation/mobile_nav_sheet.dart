import 'package:flutter/material.dart';

/// A single row in a mobile overflow navigation sheet.
class MobileNavSheetItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  final bool selected;

  const MobileNavSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.selected = false,
  });
}

/// Shows a modal bottom sheet with navigation overflow items.
Future<void> showMobileNavSheet(
  BuildContext context, {
  required String title,
  required List<MobileNavSheetItem> items,
  List<Widget>? footerWidgets,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (items.isNotEmpty || footerWidgets != null)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in items)
                      ListTile(
                        leading: Icon(
                          item.icon,
                          color:
                              item.selected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            fontWeight:
                                item.selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                            color:
                                item.selected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                          ),
                        ),
                        trailing:
                            item.badge == null
                                ? null
                                : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${item.badge}',
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                        selected: item.selected,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          item.onTap();
                        },
                      ),
                    if (footerWidgets != null) ...footerWidgets,
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
