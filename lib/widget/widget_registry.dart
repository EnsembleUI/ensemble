
import 'package:ensemble/layout/app_scroller.dart';
import 'package:ensemble/layout/box_layout.dart';
import 'package:ensemble/layout/data_grid.dart';
import 'package:ensemble/layout/flow.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/layout/stack.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/widget/fintech/finicityconnect/finicityconnect.dart';
// import 'package:ensemble/widget/camera_widget.dart';
import 'package:ensemble/widget/visualization/topology_chart.dart';
import 'package:ensemble/widget/weeklyscheduler.dart';
import 'package:ensemble/widget/Text.dart' as ensemble;
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/carousel.dart';
import 'package:ensemble/widget/chart_highcharts_builder.dart';
import 'package:ensemble/widget/divider.dart';
import 'package:ensemble/widget/dropdown.dart';
import 'package:ensemble/widget/ensemble_icon.dart';
import 'package:ensemble/widget/form_checkbox.dart';
import 'package:ensemble/widget/form_date.dart';
import 'package:ensemble/widget/form_daterange.dart';
import 'package:ensemble/widget/form_textfield.dart';
import 'package:ensemble/widget/form_time.dart';
import 'package:ensemble/widget/image.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble/widget/map.dart';
import 'package:ensemble/widget/markdown.dart';
import 'package:ensemble/widget/html.dart';
import 'package:ensemble/widget/progress_indicator.dart';
import 'package:ensemble/widget/qr_code.dart';
import 'package:ensemble/widget/rating.dart';
import 'package:ensemble/widget/signature.dart';
import 'package:ensemble/widget/spacer.dart';
import 'package:ensemble/widget/video.dart';
import 'package:ensemble/widget/visualization/barchart.dart';
import 'package:ensemble/widget/visualization/chart_js.dart';
import 'package:ensemble/widget/visualization/line_area_chart.dart';
import 'package:ensemble/widget/webview/webview.dart';

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
    Markdown.type: () => Markdown(),
    EnsembleHtml.type: () => EnsembleHtml(),
    EnsembleIcon.type: () => EnsembleIcon(),
    EnsembleImage.type: () => EnsembleImage(),
    EnsembleDivider.type: () => EnsembleDivider(),
    EnsembleSpacer.type: () => EnsembleSpacer(),

    // misc widgets
    Rating.type: () => Rating(),
    EnsembleWebView.type: () => EnsembleWebView(),
    QRCode.type: () => QRCode(),
    EnsembleProgressIndicator.type: () => EnsembleProgressIndicator(),
    EnsembleMap.type: () => EnsembleMap(),
    Carousel.type: () => Carousel(),
    Video.type: () => Video(),
    EnsembleLottie.type: () => EnsembleLottie(),
    EnsembleSignature.type: () => EnsembleSignature(),
    WeeklyScheduler.type: () => WeeklyScheduler(),
    // Camera.type: () => Camera(),

    // form fields
    EnsembleForm.type: () => EnsembleForm(),
    TextInput.type: () => TextInput(),
    Date.type: () => Date(),
    Time.type: () => Time(),
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
    EnsembleStack.type: () => EnsembleStack(),
    Flow.type: () => Flow(),
    DataGrid.type: () => DataGrid(),
    EnsembleDataRow.type: () => EnsembleDataRow(),
    TabBarOnly.type: () => TabBarOnly(),
    TabBarContainer.type: () => TabBarContainer(),
    AppScroller.type: () => AppScroller(),

    // charts
    Highcharts.type: () => Highcharts(),
    EnsembleLineChart.type: () => EnsembleLineChart(),
    EnsembleBarChart.type: () => EnsembleBarChart(),
    ChartJs.type: () => ChartJs(),
    TopologyChart.type: () => TopologyChart(),

    //domain specific or custom widgets
    FinicityConnect.type: () => FinicityConnect()
  };

}

