
import 'package:ensemble/layout/column_builder.dart';
import 'package:ensemble/layout/grid_builder.dart';
import 'package:ensemble/layout/row_builder.dart';
import 'package:ensemble/widget/Text.dart' as ensemble;
import 'package:ensemble/widget/button_builder.dart';
import 'package:ensemble/widget/chart_bubble_builder.dart';
import 'package:ensemble/widget/chart_highcharts_builder.dart';
import 'package:ensemble/widget/chart_pie_builder.dart';
import 'package:ensemble/widget/divider_builder.dart';
import 'package:ensemble/widget/form_date_input_builder.dart';
import 'package:ensemble/widget/form_textfield.dart';
import 'package:ensemble/widget/icon_builder.dart';
import 'package:ensemble/widget/image_builder.dart';
import 'package:ensemble/widget/rating_builder.dart';
import 'package:ensemble/widget/spacer_builder.dart';
import 'package:ensemble/widget/webview_builder.dart';
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

    // form fields
    TextField.type: () => TextField(),
    Button.type: () => Button(),
  };

  static Map<String, WidgetBuilderFunc> get widgetBuilders =>
      const <String, WidgetBuilderFunc> {
        // form fields
        DateInputBuilder.type: DateInputBuilder.fromDynamic,

        ImageBuilder.type: ImageBuilder.fromDynamic,
        IconBuilder.type: IconBuilder.fromDynamic,
        RatingBuilder.type: RatingBuilder.fromDynamic,
        WebViewBuilder.type: WebViewBuilder.fromDynamic,
        DividerBuilder.type: DividerBuilder.fromDynamic,
        SpacerBuilder.type: SpacerBuilder.fromDynamic,

        // charts
        ChartHighChartsBuilder.type: ChartHighChartsBuilder.fromDynamic,
        ChartPieBuilder.type: ChartPieBuilder.fromDynamic,
        ChartBubbleBuilder.type: ChartBubbleBuilder.fromDynamic,

        // layout
        ColumnBuilder.type: ColumnBuilder.fromDynamic,
        RowBuilder.type: RowBuilder.fromDynamic,

        // deprecated
        //VStackBuilder.type: VStackBuilder.fromDynamic,
        //HStackBuilder.type: HStackBuilder.fromDynamic,
        GridBuilder.type: GridBuilder.fromDynamic,
  };
}

typedef WidgetBuilderFunc = WidgetBuilder Function(
    Map<String, dynamic> props,
    Map<String, dynamic> styles,
    {WidgetRegistry? registry});
