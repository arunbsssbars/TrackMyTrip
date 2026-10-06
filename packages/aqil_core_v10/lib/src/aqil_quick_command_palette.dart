import 'package:flutter/material.dart';

/// Command palette item.
class AqilCommandAction {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onSelected;

  const AqilCommandAction({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onSelected,
  });
}

/// Instant quick-action command palette modal inspired by Linear and Superhuman.
/// Keyboard shortcut / floating trigger capable, with live filter search.
class AqilCommandModal extends StatefulWidget {
  final List<AqilCommandAction> actions;

  const AqilCommandModal({
    super.key,
    required this.actions,
  });

  static Future<void> show({
    required BuildContext context,
    required List<AqilCommandAction> actions,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: AqilCommandModal(actions: actions),
      ),
    );
  }

  @override
  State<AqilCommandModal> createState() => _AqilCommandModalState();
}

class _AqilCommandModalState extends State<AqilCommandModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.actions.where((a) {
      final q = _query.toLowerCase();
      return a.title.toLowerCase().contains(q) ||
          (a.subtitle?.toLowerCase().contains(q) ?? false);
    }).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Type a command or search...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (ctx, index) {
                final item = filtered[index];
                return ListTile(
                  dense: true,
                  leading: Icon(item.icon, size: 20, color: theme.colorScheme.primary),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    item.onSelected();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
