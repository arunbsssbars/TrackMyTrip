import 'package:flutter/material.dart';
import '../../core/services/locale_dictionary_service.dart';

class ExpeditionLocaleSelectorDialog extends StatefulWidget {
  final ValueChanged<String>? onLocaleChanged;

  const ExpeditionLocaleSelectorDialog({
    super.key,
    this.onLocaleChanged,
  });

  @override
  State<ExpeditionLocaleSelectorDialog> createState() => _ExpeditionLocaleSelectorDialogState();
}

class _ExpeditionLocaleSelectorDialogState extends State<ExpeditionLocaleSelectorDialog> {
  late String _selectedCode;
  final LocaleDictionaryService _service = LocaleDictionaryService();

  @override
  void initState() {
    super.initState();
    _selectedCode = _service.currentLocale;
  }

  void _select(String code) {
    setState(() {
      _selectedCode = code;
    });
    _service.setLocale(code);
    widget.onLocaleChanged?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.language_rounded, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expedition Language',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Select primary convoy dialect',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Language options list
                ...LocaleDictionaryService.supportedLocales.map((loc) {
                  final isSelected = loc.languageCode == _selectedCode;
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primaryContainer.withAlpha(80),
                      leading: Text(loc.flagEmoji, style: const TextStyle(fontSize: 22)),
                      title: Text(
                        loc.nativeName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(loc.englishName, style: const TextStyle(fontSize: 11)),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                          : null,
                      onTap: () => _select(loc.languageCode),
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // Live Preview Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Preview:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• ${_service.translate('start_trip', locale: _selectedCode)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• ${_service.translate('record_stoppage', locale: _selectedCode)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• ${_service.translate('emergency_sos', locale: _selectedCode)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Done button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(88, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
