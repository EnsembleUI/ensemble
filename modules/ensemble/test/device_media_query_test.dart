import 'package:ensemble/framework/device.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Device reads portrait metrics from MediaQuery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Utils.globalAppKey,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: const Size(390, 844),
            ),
            child: child!,
          );
        },
        home: const SizedBox.shrink(),
      ),
    );

    expect(Device().screenOrientation, Orientation.portrait.name);
    expect(Device().screenWidth, 390);
    expect(Device().screenHeight, 844);
  });

  testWidgets('Device reads landscape metrics from MediaQuery', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Utils.globalAppKey,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: const Size(844, 390),
            ),
            child: child!,
          );
        },
        home: const SizedBox.shrink(),
      ),
    );

    expect(Device().screenOrientation, Orientation.landscape.name);
    expect(Device().screenWidth, 844);
    expect(Device().screenHeight, 390);
  });
}
