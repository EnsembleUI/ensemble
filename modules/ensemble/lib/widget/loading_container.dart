import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/shape.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

enum ShimmerEffect { diagonal, horizontal, vertical }

/// A container that can display a loading indicator or shimmer
/// while the content is being loaded
class LoadingContainer extends StatefulWidget
    with
        Invokable,
        HasController<LoadingContainerController, LoadingContainerState> {
  static const type = 'LoadingContainer';

  LoadingContainer({Key? key}) : super(key: key);

  final LoadingContainerController _controller = LoadingContainerController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => LoadingContainerState();

  @override
  Map<String, Function> getters() {
    return {
      'isLoading': () => _controller.isLoading,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'isLoading': (value) => _controller.isLoading = Utils.optionalBool(value),
      'widget': (widget) => _controller.widget = widget,
      'loadingWidget': (loadingWidget) =>
          _controller.loadingWidget = loadingWidget,
      'baseColor': (color) => _controller.baseColor = Utils.getColor(color),
      'highlightColor': (color) =>
          _controller.highlightColor = Utils.getColor(color),
      'useShimmer': (value) =>
          _controller.useShimmer = Utils.optionalBool(value),
      'defaultShimmerPadding': (value) => _controller.padding =
          Utils.getInsets(value), // Backward compatibility
      'shimmerOptions': (options) {
        if (options is YamlMap) {
          if (options.containsKey('padding')) {
            _controller.padding = Utils.getInsets(options['padding']);
          }
          if (options.containsKey('shimmerEffect')) {
            _controller.shimmerEffect = Utils.getEnum<ShimmerEffect>(
                options['shimmerEffect'], ShimmerEffect.values);
          }
          if (options.containsKey('shimmerSpeed')) {
            _controller.shimmerSpeed =
                Utils.optionalInt(options['shimmerSpeed']);
          }
          if (options.containsKey('gradientColors')) {
            _controller.gradientColors =
                Utils.getColorList(options['gradientColors']);
          }
          if (options.containsKey('gradientStops')) {
            _controller.gradientStops =
                Utils.getList<double>(options['gradientStops']);
          }
          if (options.containsKey('min')) {
            _controller.min = Utils.optionalDouble(options['min']);
          }
          if (options.containsKey('max')) {
            _controller.max = Utils.optionalDouble(options['max']);
          }
        }
      },
    };
  }
}

class LoadingContainerController extends BoxController {
  bool? isLoading;
  bool? useShimmer;
  EdgeInsets? defaultShimmerPadding;
  Color? baseColor;
  Color? highlightColor;
  dynamic widget;
  dynamic loadingWidget;
  ShimmerEffect? shimmerEffect;
  int? shimmerSpeed;
  List<Color>? gradientColors;
  List<double>? gradientStops;
  double? min;
  double? max;
}

class LoadingContainerState extends EWidgetState<LoadingContainer> {
  @override
  Widget buildWidget(BuildContext context) {
    var loadingWidget = _buildLoadingWidget();

    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: widget._controller.isLoading == true
            ? _buildLoadingWidget()
            : _buildContentWidget());
  }

  Widget? _buildLoadingWidget() {
    Widget? loadingWidget = widget._controller.loadingWidget != null
        ? scopeManager
            ?.buildWidgetFromDefinition(widget._controller.loadingWidget)
        : null;

    return widget._controller.useShimmer == true
        ? CustomShimmer(
            linearGradient: _buildGradient(),
            shimmerEffect:
                widget._controller.shimmerEffect ?? ShimmerEffect.diagonal,
            shimmerSpeed: widget._controller.shimmerSpeed ?? 1000,
            min: widget._controller.min ?? -0.5,
            max: widget._controller.max ?? 1.5,
            child: ShimmerLoading(
                isLoading: true,
                child: loadingWidget ??
                    DefaultLoadingShape(
                        padding: widget._controller.defaultShimmerPadding)))
        : loadingWidget ?? const SizedBox.shrink();
  }

  LinearGradient _buildGradient() {
    List<Color> colors = widget._controller.gradientColors ??
        [
          widget._controller.baseColor ?? const Color(0xFFEBEBF4),
          widget._controller.highlightColor ??
              const Color(0xFFEBEBF4).withOpacity(0.3),
          widget._controller.baseColor ?? const Color(0xFFEBEBF4),
        ];

    return LinearGradient(
      begin: _getGradientBegin(),
      end: _getGradientEnd(),
      colors: colors,
      stops: widget._controller.gradientStops ?? const [0.1, 0.3, 0.4],
      tileMode: TileMode.clamp,
    );
  }

  Alignment _getGradientBegin() {
    switch (widget._controller.shimmerEffect) {
      case ShimmerEffect.horizontal:
        return Alignment.centerLeft;
      case ShimmerEffect.vertical:
        return Alignment.topCenter;
      case ShimmerEffect.diagonal:
      default:
        return Alignment.topLeft;
    }
  }

  Alignment _getGradientEnd() {
    switch (widget._controller.shimmerEffect) {
      case ShimmerEffect.horizontal:
        return Alignment.centerRight;
      case ShimmerEffect.vertical:
        return Alignment.bottomCenter;
      case ShimmerEffect.diagonal:
      default:
        return Alignment.bottomRight;
    }
  }

  Widget _buildContentWidget() {
    Widget? w =
        scopeManager?.buildWidgetFromDefinition(widget._controller.widget);
    if (w == null) {
      throw RuntimeError(
          "LoadingContainer requires a widget to render it's main content");
    }
    return w;
  }
}

/// the default loading used for shimmer
class DefaultLoadingShape extends StatelessWidget {
  const DefaultLoadingShape({super.key, this.padding});

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
      padding: padding ?? const EdgeInsets.only(top: 50, bottom: 50),
      child: const Column(
        children: [
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape()
        ],
      ));
}

class ListDetailShape extends StatelessWidget {
  const ListDetailShape({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InternalShape(
              type: ShapeVariant.square,
              width: 50,
              borderRadius: BorderRadius.all(Radius.circular(10)),
              backgroundColor: Colors.white),
          SizedBox(width: 10),
          Column(
            children: [
              InternalShape(
                  type: ShapeVariant.rectangle,
                  width: 200,
                  height: 10,
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  backgroundColor: Colors.white),
              SizedBox(height: 10),
              InternalShape(
                  type: ShapeVariant.rectangle,
                  width: 200,
                  height: 5,
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  backgroundColor: Colors.white),
            ],
          )
        ],
      );
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

class CustomShimmer extends StatefulWidget {
  static CustomShimmerState? of(BuildContext context) {
    return context.findAncestorStateOfType<CustomShimmerState>();
  }

  const CustomShimmer({
    super.key,
    required this.linearGradient,
    this.shimmerEffect = ShimmerEffect.diagonal,
    this.shimmerSpeed = 1000,
    this.child,
    this.min = -0.5,
    this.max = 1.5,
  });

  final LinearGradient linearGradient;
  final ShimmerEffect shimmerEffect;
  final int shimmerSpeed;
  final Widget? child;
  final double min;
  final double max;

  @override
  CustomShimmerState createState() => CustomShimmerState();
}

class CustomShimmerState extends State<CustomShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(
        min: widget.min,
        max: widget.max,
        period: Duration(milliseconds: widget.shimmerSpeed),
      );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  LinearGradient get gradient => LinearGradient(
        colors: widget.linearGradient.colors,
        stops: widget.linearGradient.stops,
        begin: widget.linearGradient.begin,
        end: widget.linearGradient.end,
        transform:
            _SlidingGradientTransform(slidePercent: _shimmerController.value),
      );

  bool get isSized =>
      (context.findRenderObject() as RenderBox?)?.hasSize ?? false;

  Size get size => (context.findRenderObject() as RenderBox).size;

  Offset getDescendantOffset({
    required RenderBox descendant,
    Offset offset = Offset.zero,
  }) {
    final shimmerBox = context.findRenderObject() as RenderBox;
    return descendant.localToGlobal(offset, ancestor: shimmerBox);
  }

  Listenable get shimmerChanges => _shimmerController;

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox();
  }
}

class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> {
  Listenable? _shimmerChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shimmerChanges != null) {
      _shimmerChanges!.removeListener(_onShimmerChange);
    }
    _shimmerChanges = CustomShimmer.of(context)?.shimmerChanges;
    if (_shimmerChanges != null) {
      _shimmerChanges!.addListener(_onShimmerChange);
    }
  }

  @override
  void dispose() {
    _shimmerChanges?.removeListener(_onShimmerChange);
    super.dispose();
  }

  void _onShimmerChange() {
    if (widget.isLoading) {
      setState(() {
        // update the shimmer painting.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    // Collect ancestor shimmer information.
    final shimmer = CustomShimmer.of(context)!;
    if (!shimmer.isSized) {
      // The ancestor Shimmer widget isn’t laid
      // out yet. Return an empty box.
      return const SizedBox();
    }
    final shimmerSize = shimmer.size;
    final gradient = shimmer.gradient;
    final offsetWithinShimmer = shimmer.getDescendantOffset(
      descendant: context.findRenderObject() as RenderBox,
    );

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return gradient.createShader(
          Rect.fromLTWH(
            -offsetWithinShimmer.dx,
            -offsetWithinShimmer.dy,
            shimmerSize.width,
            shimmerSize.height,
          ),
        );
      },
      child: widget.child,
    );
  }
}
