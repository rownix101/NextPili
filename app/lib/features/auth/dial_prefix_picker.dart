import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../l10n/l10n.dart';
import 'dial_prefix.dart';

/// Pick a passport dial prefix (PiliPlus-style country list).
Future<DialPrefix?> showDialPrefixPicker({
  required BuildContext context,
  required DialPrefix selected,
}) {
  return showDialog<DialPrefix>(
    context: context,
    builder: (ctx) => _DialPrefixPickerDialog(selected: selected),
  );
}

class _DialPrefixPickerDialog extends StatefulWidget {
  const _DialPrefixPickerDialog({required this.selected});

  final DialPrefix selected;

  @override
  State<_DialPrefixPickerDialog> createState() =>
      _DialPrefixPickerDialogState();
}

class _DialPrefixPickerDialogState extends State<_DialPrefixPickerDialog> {
  final _query = TextEditingController();
  late List<DialPrefix> _filtered = kDialPrefixes;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _applyFilter(String raw) {
    final q = raw.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = kDialPrefixes;
        return;
      }
      _filtered = kDialPrefixes.where((e) {
        return e.cname.toLowerCase().contains(q) ||
            e.countryId.toString().contains(q) ||
            e.displayDial.contains(q);
      }).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.authCountryCode),
      content: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.authCountrySearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: _applyFilter,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.authCountrySearchEmpty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.fgSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final item = _filtered[i];
                        final selected = item.id == widget.selected.id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(item.cname),
                          trailing: Text(
                            item.displayDial,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: selected
                                  ? colors.accent
                                  : colors.fgSecondary,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
