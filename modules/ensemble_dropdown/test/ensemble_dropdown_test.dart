import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ensemble_dropdown/ensemble_dropdown.dart'; // Replace with your actual package import

void main() {
  // Sample data for testing
  const List<String> testItems = [
    'Option 1',
    'Option 2',
    'Option 3',
    'Option 4'
  ];

  // Helper function to build dropdown for testing
  Widget buildDropdown({
    List<DropdownMenuItem<String>>? items,
    String? value,
    ValueChanged<String?>? onChanged,
    Widget? hint,
    bool isExpanded = false,
    bool isDense = false,
    ButtonStyleData? buttonStyleData,
    IconStyleData iconStyleData = const IconStyleData(),
    DropdownStyleData dropdownStyleData = const DropdownStyleData(),
    MenuItemStyleData menuItemStyleData = const MenuItemStyleData(),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: EnsembleDropdown<String>(
            items: items,
            value: value,
            onChanged: onChanged,
            hint: hint,
            isExpanded: isExpanded,
            isDense: isDense,
            buttonStyleData: buttonStyleData,
            iconStyleData: iconStyleData,
            dropdownStyleData: dropdownStyleData,
            menuItemStyleData: menuItemStyleData,
          ),
        ),
      ),
    );
  }

  // Helper function to create dropdown items
  List<DropdownMenuItem<String>> getDropdownItems() {
    return testItems
        .map((String item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ))
        .toList();
  }

  group('EnsembleDropdown widget tests', () {
    testWidgets('Dropdown displays initial value', (WidgetTester tester) async {
      const String initialValue = 'Option 2';

      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          value: initialValue,
          onChanged: (_) {},
        ),
      );

      expect(find.text(initialValue), findsOneWidget);
    });

    testWidgets('Dropdown displays hint when no value is selected',
        (WidgetTester tester) async {
      const String hintText = 'Select an option';

      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          hint: const Text(hintText),
          onChanged: (_) {},
        ),
      );

      expect(find.text(hintText), findsOneWidget);
    });

    testWidgets('Dropdown shows menu when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          onChanged: (_) {},
        ),
      );

      await tester.tap(find.byType(EnsembleDropdown<String>));
      await tester.pumpAndSettle();

      for (final String item in testItems) {
        expect(find.text(item), findsOneWidget);
      }
    });

    testWidgets('Dropdown calls onChanged when item is selected',
        (WidgetTester tester) async {
      String? selectedValue;
      const String newValue = 'Option 3';

      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          value: 'Option 1',
          onChanged: (String? value) {
            selectedValue = value;
          },
        ),
      );

      await tester.tap(find.byType(EnsembleDropdown<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text(newValue).last);
      await tester.pumpAndSettle();

      expect(selectedValue, equals(newValue));
    });

    testWidgets('Dropdown is disabled when onChanged is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          value: 'Option 1',
          onChanged: null,
        ),
      );

      // Verify the dropdown shows the selected value
      expect(find.text('Option 1'), findsOneWidget);

      // Try to tap the dropdown
      await tester.tap(find.byType(EnsembleDropdown<String>));
      await tester.pumpAndSettle();

      // No dropdown menu should appear when tapped - test by checking for absence of other options
      // that would only be visible if the menu opened
      expect(find.text('Option 3'), findsNothing); // Menu item not visible
    });

    testWidgets('Dropdown displays with custom button style',
        (WidgetTester tester) async {
      final buttonStyleData = ButtonStyleData(
        height: 50,
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.blue[100],
        ),
      );

      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          value: 'Option 1',
          onChanged: (_) {},
          buttonStyleData: buttonStyleData,
        ),
      );

      final containerFinder = find
          .descendant(
            of: find.byType(EnsembleDropdown<String>),
            matching: find.byType(Container),
          )
          .first;

      final Container container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxHeight, equals(50));
      expect(container.constraints?.maxWidth, equals(200));
      expect((container.decoration as BoxDecoration).color,
          equals(Colors.blue[100]));
    });

    testWidgets('Dropdown shows open icon when menu is open',
        (WidgetTester tester) async {
      const iconStyleData = IconStyleData(
        icon: Icon(Icons.arrow_drop_down),
        openMenuIcon: Icon(Icons.arrow_drop_up),
      );

      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          value: 'Option 1',
          onChanged: (_) {},
          iconStyleData: iconStyleData,
        ),
      );

      // Before opening menu
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_up), findsNothing);

      // Open the menu
      await tester.tap(find.byType(EnsembleDropdown<String>));
      await tester.pumpAndSettle();

      // After opening menu
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    });

    testWidgets('Dropdown with long press activation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnsembleDropdown<String>(
                items: getDropdownItems(),
                value: 'Option 1',
                onChanged: (_) {},
                openWithLongPress: true,
              ),
            ),
          ),
        ),
      );

      // Tap should not open the menu
      await tester.tap(find.byType(EnsembleDropdown<String>));
      await tester.pumpAndSettle();

      // We should only have the selected item visible (Option 1)
      // and not see other options that would be in the dropdown menu
      expect(find.text('Option 3'), findsNothing); // Menu not opened

      // Long press should open the menu
      await tester.longPress(find.byType(EnsembleDropdown<String>));
      await tester.pumpAndSettle();

      // Now we should see other options
      expect(find.text('Option 3'), findsOneWidget); // Menu is now open
    });

    testWidgets('Menu item styling is applied', (WidgetTester tester) async {
      const menuItemStyleData = MenuItemStyleData(
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: 20),
      );

      await tester.pumpWidget(
        buildDropdown(
          items: getDropdownItems(),
          value: 'Option 1',
          onChanged: (_) {},
          menuItemStyleData: menuItemStyleData,
        ),
      );

      await tester.tap(find.byType(EnsembleDropdown<String>));
      await tester.pumpAndSettle();

      // This is a simplistic check - in real tests we might use a testWidgets variant
      // that allows for more detailed inspection of rendered items
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('Dropdown menu state change callback is called',
        (WidgetTester tester) async {
      bool? isMenuOpen;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnsembleDropdown<String>(
                items: getDropdownItems(),
                value: 'Option 1',
                onChanged: (_) {},
                onMenuStateChange: (bool open) {
                  isMenuOpen = open;
                },
              ),
            ),
          ),
        ),
      );

      // Open the menu
      await tester.tap(find.byType(EnsembleDropdown<String>));
      await tester.pump();

      expect(isMenuOpen, isTrue);

      // Select an item to close the menu
      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();

      expect(isMenuOpen, isFalse);
    });
  });

  group('DropdownButtonFormField2 tests', () {
    testWidgets('FormField validation works', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      String? selectedValue = 'Option 1';
      const String errorText = 'Required field';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: DropdownButtonFormField2<String>(
                decoration: const InputDecoration(
                  labelText: 'Select an option',
                ),
                items: getDropdownItems(),
                value: selectedValue,
                onChanged: (String? value) {
                  selectedValue = value;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return errorText;
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Initially the form should be valid
      expect(formKey.currentState!.validate(), isTrue);

      // Set value to null (this would typically happen through onChanged)
      selectedValue = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: DropdownButtonFormField2<String>(
                decoration: const InputDecoration(
                  labelText: 'Select an option',
                ),
                items: getDropdownItems(),
                value: selectedValue,
                onChanged: (String? value) {
                  selectedValue = value;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return errorText;
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Validate should now return false and show the error
      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text(errorText), findsOneWidget);
    });

    testWidgets('FormField works with decoration', (WidgetTester tester) async {
      const String labelText = 'Test Label';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField2<String>(
              decoration: const InputDecoration(
                labelText: labelText,
                border: OutlineInputBorder(),
              ),
              items: getDropdownItems(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text(labelText), findsOneWidget);
      expect(find.byType(InputDecorator), findsOneWidget);
    });
  });
}
