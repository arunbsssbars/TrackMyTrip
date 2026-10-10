import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/widgets/cloudinary_progressive_image.dart';

void main() {
  testWidgets('CloudinaryProgressiveImage renders Cloudinary URLs with LQIP stack', (tester) async {
    const cloudinaryUrl = 'https://res.cloudinary.com/testcloud/image/upload/v12345/trip_photo.jpg';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CloudinaryProgressiveImage(
            imageUrl: cloudinaryUrl,
            width: 200,
            height: 150,
          ),
        ),
      ),
    );

    // Should contain a Stack with the 2 Image widgets (LQIP placeholder + target high-res)
    expect(find.byType(CloudinaryProgressiveImage), findsOneWidget);
    final stackFinder = find.descendant(
      of: find.byType(CloudinaryProgressiveImage),
      matching: find.byType(Stack),
    );
    expect(stackFinder, findsOneWidget);
    expect(find.descendant(of: stackFinder, matching: find.byType(Image)), findsNWidgets(2));
  });

  testWidgets('CloudinaryProgressiveImage renders error fallback on invalid data URI', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CloudinaryProgressiveImage(
            imageUrl: 'data:image/jpeg;base64,invalid_corrupt_base64_data!!!',
            width: 100,
            height: 100,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image_rounded), findsOneWidget);
  });

  testWidgets('CloudinaryProgressiveImage renders custom placeholder when URL is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CloudinaryProgressiveImage(
            imageUrl: '',
            width: 100,
            height: 100,
            placeholder: Text('Custom Placeholder'),
          ),
        ),
      ),
    );

    expect(find.text('Custom Placeholder'), findsOneWidget);
  });
}
