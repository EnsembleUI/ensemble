import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class TestUtils {
  /// wraps the test widget in MaterialApp and Scaffold
  static Widget wrapTestWidget(Widget widget) =>
      MaterialApp(home: Scaffold(body: widget));

  static Widget wrapTestWidgetWithScope(Widget widget) {
    MockBuildContext buildContext = MockBuildContext();
    ScopeManager scopeManager =
        ScopeManager(DataContext(buildContext: buildContext), PageData());
    DataScopeWidget dataScopeWidget =
        DataScopeWidget(scopeManager: scopeManager, child: widget);

    when(buildContext.dependOnInheritedWidgetOfExactType<DataScopeWidget>())
        .thenReturn(dataScopeWidget);

    return MaterialApp(home: Scaffold(body: dataScopeWidget));
  }
}

class MockBuildContext extends Mock implements BuildContext {}
