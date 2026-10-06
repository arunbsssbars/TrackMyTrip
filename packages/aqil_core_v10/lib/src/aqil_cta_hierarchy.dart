
/// Semantic role of an actionable CTA button.
enum AqilButtonRole {
  primary,   // High-emphasis filled button (Save, Checkout, Submit) - only 1 per visible viewport
  secondary, // Medium-emphasis outlined or tonal button (Cancel, Back)
  tertiary,  // Low-emphasis text-only button / inline link
  destructive, // Danger action (Delete, Remove)
}

/// A button hierarchy conformance auditor verifying adherence to the Von Restorff effect
/// (guaranteeing that exactly 1 primary CTA commands attention per visible screen viewport).
class AqilCtaHierarchyAuditor {
  /// Audits a collection of visible action buttons in a view.
  static String? auditButtonCollection(List<AqilButtonRole> buttons, {String screenName = 'Screen'}) {
    final primaryCount = buttons.where((b) => b == AqilButtonRole.primary).length;

    if (primaryCount > 1) {
      return '$screenName has $primaryCount primary CTAs in the same viewport, causing visual competition and decision paralysis (violates Von Restorff isolation effect). Recommend downgrading secondary choices to outlined/tonal buttons.';
    }

    if (primaryCount == 0 && buttons.isNotEmpty) {
      return '$screenName has ${buttons.length} actions but 0 primary CTAs, leaving the user without a clear next step.';
    }

    return null;
  }
}
