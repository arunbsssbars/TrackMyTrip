import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/utils/date_formatter.dart';

void main() {
  group('PDF Export Date & Stoppage Formatting Tests', () {
    test('Arrived title uses ASCII "at" delimiter without Unicode bullet glyphs', () {
      final arrivalTime = DateTime(2026, 10, 10, 14, 30);
      final formattedDate = DateFormatter.formatShortDate(arrivalTime);
      final formattedTime = DateFormatter.formatTimeOnly(arrivalTime);
      final arrivedHeader = 'Category: Food  |  Arrived: $formattedDate at $formattedTime';

      // Verify clean ASCII text
      expect(arrivedHeader, contains('Oct 10, 2026 at 2:30 PM'));
      // Verify no Unicode bullet character (\u2022) which triggers Type 1 PDF font icon distortion
      expect(arrivedHeader.contains('\u2022'), isFalse);
      expect(arrivedHeader.contains('•'), isFalse);
    });
  });
}
