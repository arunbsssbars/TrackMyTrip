import 'package:flutter/material.dart';

/// Category of production UI error ingested from Real User Monitoring (RUM).
enum RumErrorCategory {
  renderFlexOverflow,
  unhandledGestureException,
  fontScaleTruncation,
  viewportUnboundedHeight,
  contrastAnomaly,
}

/// A structured telemetry incident captured from production users (AQIL Frontier 6).
class RumTelemetryIncident {
  final String incidentId;
  final RumErrorCategory category;
  final String screenRoute;
  final Size viewportSize;
  final double devicePixelRatio;
  final double textScaleFactor;
  final String errorMessage;
  final double? overflowPixels;
  final String? failingWidgetType;
  final DateTime timestamp;

  const RumTelemetryIncident({
    required this.incidentId,
    required this.category,
    required this.screenRoute,
    required this.viewportSize,
    this.devicePixelRatio = 2.0,
    this.textScaleFactor = 1.0,
    required this.errorMessage,
    this.overflowPixels,
    this.failingWidgetType,
    required this.timestamp,
  });

  /// Serializes into JSON telemetry dictionary.
  Map<String, dynamic> toJson() => {
        'incidentId': incidentId,
        'category': category.name,
        'screenRoute': screenRoute,
        'viewportWidth': viewportSize.width,
        'viewportHeight': viewportSize.height,
        'devicePixelRatio': devicePixelRatio,
        'textScaleFactor': textScaleFactor,
        'errorMessage': errorMessage,
        'overflowPixels': overflowPixels,
        'failingWidgetType': failingWidgetType,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Parses an incident from a JSON dictionary.
  factory RumTelemetryIncident.fromJson(Map<String, dynamic> json) {
    return RumTelemetryIncident(
      incidentId: json['incidentId'] as String,
      category: RumErrorCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => RumErrorCategory.renderFlexOverflow,
      ),
      screenRoute: json['screenRoute'] as String? ?? 'unknown',
      viewportSize: Size(
        (json['viewportWidth'] as num?)?.toDouble() ?? 393.0,
        (json['viewportHeight'] as num?)?.toDouble() ?? 852.0,
      ),
      devicePixelRatio: (json['devicePixelRatio'] as num?)?.toDouble() ?? 2.0,
      textScaleFactor: (json['textScaleFactor'] as num?)?.toDouble() ?? 1.0,
      errorMessage: json['errorMessage'] as String? ?? '',
      overflowPixels: (json['overflowPixels'] as num?)?.toDouble(),
      failingWidgetType: json['failingWidgetType'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Production RUM Feedback Loop & Test Case Synthesizer (AQIL Frontier 6).
///
/// Ingests production crash logs (Crashlytics, Sentry, Datadog RUM) and
/// automatically synthesizes reproducible Flutter widget tests replicating
/// the exact production viewport, dynamic font scaler, and route state.
class AqilRumSynthesizer {
  /// Parses raw Flutter framework error text into a structured [RumTelemetryIncident].
  static RumTelemetryIncident parseFlutterErrorLog(
    String rawErrorLog, {
    String incidentId = 'INC-RUM-001',
    String screenRoute = '/kiosk',
    Size viewport = const Size(360, 800),
    double textScale = 1.35,
  }) {
    RumErrorCategory category = RumErrorCategory.renderFlexOverflow;
    double? overflowPx;
    String? widgetType;

    if (rawErrorLog.contains('RenderFlex overflowed')) {
      category = RumErrorCategory.renderFlexOverflow;
      final overflowMatch = RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(rawErrorLog);
      if (overflowMatch != null) {
        overflowPx = double.tryParse(overflowMatch.group(1)!);
      }
    } else if (rawErrorLog.contains('Vertical viewport was given unbounded height')) {
      category = RumErrorCategory.viewportUnboundedHeight;
    } else if (rawErrorLog.contains('GestureDetector') || rawErrorLog.contains('pointer')) {
      category = RumErrorCategory.unhandledGestureException;
    }

    final widgetMatch = RegExp(r'The following assertion was thrown during \w+:.*?in (\w+)', dotAll: true)
        .firstMatch(rawErrorLog);
    if (widgetMatch != null) {
      widgetType = widgetMatch.group(1);
    }

    return RumTelemetryIncident(
      incidentId: incidentId,
      category: category,
      screenRoute: screenRoute,
      viewportSize: viewport,
      textScaleFactor: textScale,
      errorMessage: rawErrorLog.trim().split('\n').first,
      overflowPixels: overflowPx,
      failingWidgetType: widgetType,
      timestamp: DateTime.now(),
    );
  }

  /// Synthesizes an executable Dart widget test source string from a production incident.
  static String synthesizeExecutableWidgetTest(
    RumTelemetryIncident incident, {
    String testGroupName = 'RUM Production Regression Suite',
    String widgetConstructor = 'const Placeholder()',
  }) {
    final buffer = StringBuffer();
    buffer.writeln("// Auto-synthesized test by AQIL RUM Engine for ${incident.incidentId}");
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import 'package:flutter_test/flutter_test.dart';");
    buffer.writeln("import 'helpers/ui_test_helper.dart';");
    buffer.writeln();
    buffer.writeln("void main() {");
    buffer.writeln("  group('$testGroupName', () {");
    buffer.writeln("    testWidgets('Replay production ${incident.incidentId} - ${incident.category.name}', (WidgetTester tester) async {");
    buffer.writeln("      // 1. Configure exact production hardware viewport and font scaling");
    buffer.writeln("      tester.view.physicalSize = const Size(${incident.viewportSize.width}, ${incident.viewportSize.height}) * ${incident.devicePixelRatio};");
    buffer.writeln("      tester.view.devicePixelRatio = ${incident.devicePixelRatio};");
    buffer.writeln();
    buffer.writeln("      // 2. Pump target screen under production conditions");
    buffer.writeln("      await tester.pumpWidget(");
    buffer.writeln("        MaterialApp(");
    buffer.writeln("          home: MediaQuery(");
    buffer.writeln("            data: const MediaQueryData(");
    buffer.writeln("              size: Size(${incident.viewportSize.width}, ${incident.viewportSize.height}),");
    buffer.writeln("              textScaler: TextScaler.linear(${incident.textScaleFactor}),");
    buffer.writeln("            ),");
    buffer.writeln("            child: Scaffold(");
    buffer.writeln("              body: $widgetConstructor,");
    buffer.writeln("            ),");
    buffer.writeln("          ),");
    buffer.writeln("        ),");
    buffer.writeln("      );");
    buffer.writeln("      await tester.pumpAndSettle();");
    buffer.writeln();
    buffer.writeln("      // 3. Assert zero uncaught framework exceptions and layout overflows");
    buffer.writeln("      expect(tester.takeException(), isNull);");
    buffer.writeln("      tester.view.resetPhysicalSize();");
    buffer.writeln("      tester.view.resetDevicePixelRatio();");
    buffer.writeln("    });");
    buffer.writeln("  });");
    buffer.writeln("}");

    return buffer.toString();
  }

  /// Aggregates a batch of RUM incidents and computes an SLA triage report.
  static Map<String, dynamic> generateSlaTriageReport(List<RumTelemetryIncident> incidents) {
    int total = incidents.length;
    int overflows = 0;
    int gestures = 0;
    int unbounded = 0;
    double maxOverflowPx = 0.0;

    for (final inc in incidents) {
      switch (inc.category) {
        case RumErrorCategory.renderFlexOverflow:
          overflows++;
          if (inc.overflowPixels != null && inc.overflowPixels! > maxOverflowPx) {
            maxOverflowPx = inc.overflowPixels!;
          }
          break;
        case RumErrorCategory.unhandledGestureException:
          gestures++;
          break;
        case RumErrorCategory.viewportUnboundedHeight:
          unbounded++;
          break;
        default:
          break;
      }
    }

    return {
      'totalIncidents': total,
      'overflowCount': overflows,
      'gestureErrorCount': gestures,
      'unboundedHeightCount': unbounded,
      'maxOverflowPixels': maxOverflowPx,
      'criticalityScore': (overflows * 3.0 + unbounded * 2.5 + gestures * 1.5).clamp(0.0, 100.0),
    };
  }
}
