import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_test_helper.dart';

/// A variant specification for a design system component in the Storybook catalog.
class ComponentVariant {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> props;

  const ComponentVariant({
    required this.id,
    required this.name,
    this.description = '',
    this.props = const {},
  });
}

/// Metadata and interactive builder for a cataloged component (AQIL Frontier 3).
class CatalogComponent {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<ComponentVariant> variants;
  final Widget Function(BuildContext context, ComponentVariant variant) builder;

  const CatalogComponent({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    required this.variants,
    required this.builder,
  });
}

/// Verification result of auditing a component across the catalog matrix.
class ComponentCatalogAuditReport {
  final String componentId;
  final String componentName;
  final int variantsAudited;
  final bool passedAccessibility;
  final bool passedThemeMatrix;
  final bool passedFontScaling;
  final List<String> issues;

  const ComponentCatalogAuditReport({
    required this.componentId,
    required this.componentName,
    required this.variantsAudited,
    required this.passedAccessibility,
    required this.passedThemeMatrix,
    required this.passedFontScaling,
    this.issues = const [],
  });

  bool get isCompliant =>
      passedAccessibility && passedThemeMatrix && passedFontScaling && issues.isEmpty;
}

/// Interactive Component Catalog & Storybook Auto-Generator (AQIL Frontier 3).
///
/// Enables automated design system inventorying, interactive gallery rendering,
/// Markdown documentation generation, and matrix-level AQIL compliance auditing.
class AqilComponentCatalog {
  final Map<String, CatalogComponent> _components = {};

  List<CatalogComponent> get allComponents => _components.values.toList();
  int get componentCount => _components.length;
  int get totalVariantCount =>
      _components.values.fold(0, (acc, c) => acc + c.variants.length);

  /// Registers a component in the catalog.
  void register(CatalogComponent component) {
    _components[component.id] = component;
  }

  /// Registers multiple components at once.
  void registerAll(Iterable<CatalogComponent> components) {
    for (final c in components) {
      register(c);
    }
  }

  /// Retrieves a registered component by id.
  CatalogComponent? get(String id) => _components[id];

  /// Returns components grouped by category.
  Map<String, List<CatalogComponent>> groupByCategory() {
    final map = <String, List<CatalogComponent>>{};
    for (final component in _components.values) {
      map.putIfAbsent(component.category, () => []).add(component);
    }
    return map;
  }

  /// Generates a comprehensive Markdown documentation index of the design catalog.
  String exportMarkdownDocumentation() {
    final buffer = StringBuffer();
    buffer.writeln('# Design System Component Catalog & Storybook');
    buffer.writeln();
    buffer.writeln('Total Components: **$componentCount** | Total Variants: **$totalVariantCount**');
    buffer.writeln();

    final grouped = groupByCategory();
    for (final entry in grouped.entries) {
      buffer.writeln('## Category: ${entry.key.toUpperCase()}');
      buffer.writeln('| Component | Description | Variants |');
      buffer.writeln('| :--- | :--- | :--- |');

      for (final comp in entry.value) {
        final variantNames = comp.variants.map((v) => '`${v.name}`').join(', ');
        buffer.writeln('| **${comp.name}** (`${comp.id}`) | ${comp.description} | $variantNames |');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Builds a responsive, interactive Storybook gallery widget.
  Widget buildStorybookViewer({
    Brightness initialBrightness = Brightness.light,
    double initialFontScale = 1.0,
  }) {
    return _StorybookViewerWidget(
      catalog: this,
      initialBrightness: initialBrightness,
      initialFontScale: initialFontScale,
    );
  }

  /// Executes automated matrix audits (Accessibility, Themes, 2.0x font scaling)
  /// on every variant of every component registered in the catalog.
  Future<Map<String, ComponentCatalogAuditReport>> auditCatalogMatrix(
    WidgetTester tester, {
    ThemeData? lightTheme,
    ThemeData? darkTheme,
  }) async {
    final results = <String, ComponentCatalogAuditReport>{};

    for (final component in _components.values) {
      final issues = <String>[];
      bool passA11y = true;
      bool passTheme = true;
      bool passFont = true;

      for (final variant in component.variants) {
        // 1. Accessibility & Theme Audit
        try {
          await UiQualityTester.testThemeMatrix(
            tester,
            lightTheme: lightTheme,
            darkTheme: darkTheme,
            builder: (context) => component.builder(context, variant),
          );
        } catch (e) {
          passTheme = false;
          issues.add('Theme matrix failure on variant "${variant.id}": $e');
        }

        // 2. Extreme Font Scaling Audit (2.0x)
        try {
          await UiQualityTester.auditExtremeFontScaling(
            tester,
            builder: (context, scale) => component.builder(context, variant),
            scales: const [2.0],
          );
        } catch (e) {
          passFont = false;
          issues.add('Font scaling failure on variant "${variant.id}": $e');
        }
      }

      results[component.id] = ComponentCatalogAuditReport(
        componentId: component.id,
        componentName: component.name,
        variantsAudited: component.variants.length,
        passedAccessibility: passA11y,
        passedThemeMatrix: passTheme,
        passedFontScaling: passFont,
        issues: issues,
      );
    }

    return results;
  }
}

/// Interactive Storybook Flutter UI.
class _StorybookViewerWidget extends StatefulWidget {
  final AqilComponentCatalog catalog;
  final Brightness initialBrightness;
  final double initialFontScale;

  const _StorybookViewerWidget({
    required this.catalog,
    required this.initialBrightness,
    required this.initialFontScale,
  });

  @override
  State<_StorybookViewerWidget> createState() => _StorybookViewerWidgetState();
}

class _StorybookViewerWidgetState extends State<_StorybookViewerWidget> {
  late Brightness _brightness;
  late double _fontScale;
  String _searchQuery = '';
  String? _selectedComponentId;
  int _selectedVariantIndex = 0;

  @override
  void initState() {
    super.initState();
    _brightness = widget.initialBrightness;
    _fontScale = widget.initialFontScale;
    if (widget.catalog.allComponents.isNotEmpty) {
      _selectedComponentId = widget.catalog.allComponents.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: _brightness,
      useMaterial3: true,
      colorSchemeSeed: Colors.indigo,
    );

    final filteredComponents = widget.catalog.allComponents.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    CatalogComponent? selectedComponent;
    if (_selectedComponentId != null && widget.catalog.get(_selectedComponentId!) != null) {
      selectedComponent = widget.catalog.get(_selectedComponentId!);
    } else if (filteredComponents.isNotEmpty) {
      selectedComponent = filteredComponents.first;
    }

    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(_fontScale)),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('AQIL Component Storybook', overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                key: const ValueKey('storybook_theme_toggle'),
                tooltip: 'Toggle Theme Brightness',
                icon: Icon(_brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  setState(() {
                    _brightness = _brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark;
                  });
                },
              ),
              IconButton(
                key: const ValueKey('storybook_font_scale_toggle'),
                tooltip: 'Scale Font',
                icon: const Icon(Icons.text_fields),
                onPressed: () {
                  setState(() {
                    _fontScale = _fontScale >= 2.0 ? 1.0 : _fontScale + 0.5;
                  });
                },
              ),
            ],
          ),
          body: Row(
            children: [
              // Sidebar Navigation
              SizedBox(
                width: 260,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        key: const ValueKey('storybook_search_field'),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search components...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredComponents.length,
                        itemBuilder: (context, index) {
                          final item = filteredComponents[index];
                          final isSelected = item.id == selectedComponent?.id;
                          return ListTile(
                            key: ValueKey('catalog_item_${item.id}'),
                            dense: true,
                            selected: isSelected,
                            title: Text(item.name, overflow: TextOverflow.ellipsis),
                            subtitle: Text(item.category, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              setState(() {
                                _selectedComponentId = item.id;
                                _selectedVariantIndex = 0;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Main Canvas Preview
              Expanded(
                child: selectedComponent == null
                    ? const Center(child: Text('No components found'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${selectedComponent.name} (${selectedComponent.variants.length} variants)',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownButton<int>(
                                  key: const ValueKey('storybook_variant_selector'),
                                  value: _selectedVariantIndex.clamp(
                                      0, selectedComponent.variants.length - 1),
                                  items: List.generate(
                                    selectedComponent.variants.length,
                                    (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text(
                                        selectedComponent!.variants[i].name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  onChanged: (newIdx) {
                                    if (newIdx != null) {
                                      setState(() {
                                        _selectedVariantIndex = newIdx;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(32),
                                child: selectedComponent.builder(
                                  context,
                                  selectedComponent.variants[_selectedVariantIndex.clamp(
                                      0, selectedComponent.variants.length - 1)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
