
import 'package:ensemble/layout/box_layout.dart';
import 'package:ensemble/layout/data_grid.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/layout/stack.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/widget/Text.dart' as ensemble;
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/chart_bubble_builder.dart';
import 'package:ensemble/widget/chart_highcharts_builder.dart';
import 'package:ensemble/widget/chart_pie_builder.dart';
import 'package:ensemble/widget/divider.dart';
import 'package:ensemble/widget/dropdown.dart';
import 'package:ensemble/widget/ensemble_icon.dart';
import 'package:ensemble/widget/form_checkbox.dart';
import 'package:ensemble/widget/form_daterange.dart';
import 'package:ensemble/widget/form_textfield.dart';
import 'package:ensemble/widget/image.dart';
import 'package:ensemble/widget/qr_code.dart';
import 'package:ensemble/widget/rating.dart';
import 'package:ensemble/widget/spacer.dart';
import 'package:ensemble/widget/visualization/line_area_chart.dart';
import 'package:ensemble/widget/webview.dart';
import 'package:ensemble/widget/widget_builder.dart';

class WidgetRegistry {
  WidgetRegistry({
    this.debugLabel
  });
  final String? debugLabel;

  static final WidgetRegistry instance = WidgetRegistry(
    debugLabel: 'default',
  );

  static Map<String, Function> get widgetMap => <String, Function> {
    ensemble.Text.type: () => ensemble.Text(),
    EnsembleIcon.type: () => EnsembleIcon(),
    EnsembleImage.type: () => EnsembleImage(),
    EnsembleDivider.type: () => EnsembleDivider(),
    EnsembleSpacer.type: () => EnsembleSpacer(),

    // misc widgets
    Rating.type: () => Rating(),
    EnsembleWebView.type: () => EnsembleWebView(),
    QRCode.type: () => QRCode(),

    // form fields
    EnsembleForm.type: () => EnsembleForm(),
    TextInput.type: () => TextInput(),
    DateRange.type: () => DateRange(),
    PasswordInput.type: () => PasswordInput(),
    EnsembleCheckbox.type: () => EnsembleCheckbox(),
    EnsembleSwitch.type: () => EnsembleSwitch(),
    Dropdown.type: () => Dropdown(),
    Button.type: () => Button(),

    // containers
    Column.type: () => Column(),
    Row.type: () => Row(),
    Flex.type: () => Flex(),
    Stack.type: () => Stack(),
    DataGrid.type: () => DataGrid(),
    EnsembleDataRow.type: () => EnsembleDataRow(),
    EnsembleTabBar.type: () => EnsembleTabBar(),

    // charts
    Highcharts.type: () => Highcharts(),
    EnsembleLineChart.type: () => EnsembleLineChart(),
  };

  @Deprecated("Use widgetMap instead")
  static Map<String, WidgetBuilderFunc> get widgetBuilders =>
      const <String, WidgetBuilderFunc> {
        // charts
        //ChartPieBuilder.type: ChartPieBuilder.fromDynamic,
        //ChartBubbleBuilder.type: ChartBubbleBuilder.fromDynamic,

  };
}

typedef WidgetBuilderFunc = WidgetBuilder Function(
    Map<String, dynamic> props,
    Map<String, dynamic> styles,
    {WidgetRegistry? registry});
