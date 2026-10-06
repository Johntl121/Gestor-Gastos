import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Lazy list test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 100,
            itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
          ),
        ),
      ),
    );

    // This should fail with Bad state: No element
    await tester.ensureVisible(find.text('Item 50'));
  });
}