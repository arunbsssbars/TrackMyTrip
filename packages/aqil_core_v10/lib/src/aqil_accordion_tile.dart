import 'package:flutter/material.dart';

/// An interactive collapsible accordion / disclosure tile with silky height animation,
/// rotational chevron arrow, and optional subtle border dividers inspired by Linear and Notion.
class AqilAccordionTile extends StatefulWidget {
  final Widget title;
  final Widget content;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry padding;

  const AqilAccordionTile({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
  });

  @override
  State<AqilAccordionTile> createState() => _AqilAccordionTileState();
}

class _AqilAccordionTileState extends State<AqilAccordionTile>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(10.0),
          child: Padding(
            padding: widget.padding,
            child: Row(
              children: [
                Expanded(child: widget.title),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: EdgeInsets.only(
              left: (widget.padding as EdgeInsets).left,
              right: (widget.padding as EdgeInsets).right,
              bottom: 12.0,
            ),
            child: widget.content,
          ),
          crossFadeState:
              _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 240),
          sizeCurve: Curves.easeInOutCubic,
        ),
      ],
    );
  }
}
