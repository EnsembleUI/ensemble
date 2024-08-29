import 'package:ensemble/framework/stub/ensemble_bracket.dart';
import 'package:ensemble/framework/stub/ensemble_chat.dart';
import 'package:ensemble/framework/stub/qr_code_scanner.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/layout/app_scroller.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/box/fitted_box_layout.dart';
import 'package:ensemble/layout/box/flex_box_layout.dart';
import 'package:ensemble/layout/data_grid.dart';
import 'package:ensemble/layout/flow.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/layout/grid_view.dart';
import 'package:ensemble/layout/list_view.dart';
import 'package:ensemble/layout/stack.dart';
import 'package:ensemble/layout/tab/scrollable_tab_bar.dart';
import 'package:ensemble/layout/tab_bar.dart';
import 'package:ensemble/layout/toggle_container.dart';
import 'package:ensemble/module/location_module.dart';
import 'package:ensemble/widget/Toggle.dart';
import 'package:ensemble/widget/address.dart';
import 'package:ensemble/widget/avatar.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/calendar.dart';
import 'package:ensemble/widget/checkbox.dart';
import 'package:ensemble/widget/countdown.dart';
import 'package:ensemble/widget/inline_timepicker.dart';
import 'package:ensemble/widget/radio/radio_button.dart';
import 'package:ensemble/widget/radio/radio_group.dart';
import 'package:ensemble/widget/static_map.dart';
import 'package:ensemble/widget/shape.dart';
import 'package:ensemble/widget/carousel.dart';
import 'package:ensemble/widget/chart_highcharts_builder.dart';
import 'package:ensemble/widget/conditional.dart';
import 'package:ensemble/widget/confirmation_input.dart';
import 'package:ensemble/widget/divider.dart';
import 'package:ensemble/widget/ensemble_icon.dart';
import 'package:ensemble/widget/fintech/finicityconnect/finicityconnect.dart';
import 'package:ensemble/widget/form_daterange.dart';
import 'package:ensemble/widget/html.dart';
import 'package:ensemble/widget/icon_button.dart';
import 'package:ensemble/widget/image.dart';
import 'package:ensemble/widget/image_cropper.dart';
import 'package:ensemble/widget/input/dropdown.dart';
import 'package:ensemble/widget/input/form_date.dart';
import 'package:ensemble/widget/input/form_textfield.dart';
import 'package:ensemble/widget/input/form_time.dart';
import 'package:ensemble/widget/input/slider.dart';
import 'package:ensemble/widget/loading_container.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble/widget/markdown.dart';
import 'package:ensemble/widget/popup_menu.dart';
import 'package:ensemble/widget/progress_indicator.dart';
import 'package:ensemble/widget/qr_code.dart';
import 'package:ensemble/widget/rating.dart';
import 'package:ensemble/widget/signature.dart';
import 'package:ensemble/widget/spacer.dart';
import 'package:ensemble/widget/staggered_grid.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:ensemble/widget/switch.dart';
import 'package:ensemble/widget/text.dart';
import 'package:ensemble/widget/toggle_button.dart';
import 'package:ensemble/widget/video.dart';
import 'package:ensemble/widget/visualization/barchart.dart';
import 'package:ensemble/widget/visualization/chart_js.dart';
import 'package:ensemble/widget/visualization/line_area_chart.dart';
import 'package:ensemble/widget/visualization/topology_chart.dart';
import 'package:ensemble/widget/webview/webview.dart';
import 'package:ensemble/widget/youtube/youtube.dart';
import 'package:ensemble/widget/weeklyscheduler.dart';
import 'package:get_it/get_it.dart';

import 'fintech/tabapayconnect.dart';

class WidgetRegistry {
  static final WidgetRegistry _instance = WidgetRegistry._();

  WidgetRegistry._();

  factory WidgetRegistry() => _instance;

  /// all statically-known widgets should be registered here.
  /// widgets can be dynamically registered (or overridden) by calling registerWidget()
  final Map<String, Function> _registeredWidgets = {
    Avatar.type: Avatar.build,
    Shape.type: Shape.build,
    StaticMap.type: StaticMap.build,
    InlineTimePicker.type: InlineTimePicker.build,
  };

  /// register or override a widget
  void registerWidget(String widgetType, Function widgetFunc) {
    _registeredWidgets[widgetType] = widgetFunc;
  }

  Map<String, Function> get widgetMap => _registeredWidgets;

  static Map<String, Function> get pageWidgetMap =>
      <String, Function>{Footer.type: () => Footer()};

  /// Legacy: To be moved to _registeredWidgets;
  static Map<String, Function> get legacyWidgetMap => <String, Function>{
        EnsembleText.type: () => EnsembleText(),
        Markdown.type: () => Markdown(),
        EnsembleHtml.type: () => EnsembleHtml(),
        EnsembleIcon.type: () => EnsembleIcon(),
        EnsembleImage.type: () => EnsembleImage(),
        EnsembleImageCropper.type: () => EnsembleImageCropper(),
        EnsembleDivider.type: () => EnsembleDivider(),
        EnsembleSpacer.type: () => EnsembleSpacer(),
        Toggle.type: () => Toggle(),

        // misc widgets
        Address.type: () => Address(),
        Rating.type: () => Rating(),
        EnsembleWebView.type: () => EnsembleWebView(),
        QRCode.type: () => QRCode(),
        EnsembleProgressIndicator.type: () => EnsembleProgressIndicator(),
        EnsembleMap.type: () => GetIt.instance<EnsembleMap>(),
        'Maps': () => GetIt.instance<EnsembleMap>(), // backward compatible
        Carousel.type: () => Carousel(),
        Video.type: () => Video(),
        YouTube.type: () => YouTube(),
        EnsembleLottie.type: () => EnsembleLottie(),
        EnsembleSignature.type: () => EnsembleSignature(),
        WeeklyScheduler.type: () => WeeklyScheduler(),
        Conditional.type: () => Conditional(),
        SignInWithGoogle.type: () => GetIt.instance<SignInWithGoogle>(),
        SignInWithApple.type: () => GetIt.instance<SignInWithApple>(),
        ConnectWithGoogle.type: () => GetIt.instance<ConnectWithGoogle>(),
        ConnectWithMicrosoft.type: () => GetIt.instance<ConnectWithMicrosoft>(),
        SignInWithAuth0.type: () => GetIt.instance<SignInWithAuth0>(),
        EnsembleChat.type: () => GetIt.instance<EnsembleChat>(),
        EnsembleBracket.type: () => GetIt.instance<EnsembleBracket>(),
        EnsembleQRCodeScanner.type: () =>
            GetIt.instance<EnsembleQRCodeScanner>(),
        PopupMenu.type: () => PopupMenu(),
        EnsembleCalendar.type: () => EnsembleCalendar(),
        Countdown.type: () => Countdown(),

        // form fields
        RadioButton.type: () => RadioButton(),
        EnsembleForm.type: () => EnsembleForm(),
        TextInput.type: () => TextInput(),
        ConfirmationInput.type: () => ConfirmationInput(),
        Date.type: () => Date(),
        Time.type: () => Time(),
        DateRange.type: () => DateRange(),
        PasswordInput.type: () => PasswordInput(),
        EnsembleCheckbox.type: () => EnsembleCheckbox(),
        EnsembleSwitch.type: () => EnsembleSwitch(),
        EnsembleTripleSwitch.type: () => EnsembleTripleSwitch(),
        Dropdown.type: () => Dropdown(),
        RadioGroup.type: () => RadioGroup(),
        Button.type: () => Button(),
        EnsembleIconButton.type: () => EnsembleIconButton(),
        EnsembleToggleButton.type: () => EnsembleToggleButton(),
        EnsembleSlider.type: () => EnsembleSlider(),

        // containers
        ToggleContainer.type: () => ToggleContainer(),
        FlexRow.type: () => FlexRow(),
        FlexColumn.type: () => FlexColumn(),
        FittedRow.type: () => FittedRow(),
        FittedColumn.type: () => FittedColumn(),
        Column.type: () => Column(),
        Row.type: () => Row(),
        ListView.type: () => ListView(),
        GridView.type: () => GridView(),
        EnsembleStaggeredGrid.type: () => EnsembleStaggeredGrid(),
        Flex.type: () => Flex(),
        EnsembleStack.type: () => EnsembleStack(),
        Flow.type: () => Flow(),
        DataGrid.type: () => DataGrid(),
        EnsembleDataRow.type: () => EnsembleDataRow(),
        TabBarOnly.type: () => TabBarOnly(),
        TabBarContainer.type: () => TabBarContainer(),
        ScrollableTabBar.type: () => ScrollableTabBar(),
        AppScroller.type: () => AppScroller(),
        LoadingContainer.type: () => LoadingContainer(),

        // charts
        Highcharts.type: () => Highcharts(),
        EnsembleLineChart.type: () => EnsembleLineChart(),
        EnsembleBarChart.type: () => EnsembleBarChart(),
        ChartJs.type: () => ChartJs(),
        TopologyChart.type: () => TopologyChart(),

        //domain specific or custom widgets
        FinicityConnect.type: () => FinicityConnect(),
        TabaPayConnect.type: () => TabaPayConnect(),

        // handling common GPT widget mistakes
        "Container": () => Column(),
      };
}
