import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Vertical, full-viewport paged feed for Reels-style content.
///
/// The component owns scrolling/page identity only. Feed data, pagination,
/// selection, playback and UI stay in Ensemble YAML.
// ignore: must_be_immutable
class ReelsView extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<ReelsViewController, ReelsViewState> {
  static const type = 'ReelsView';

  ReelsView({Key? key}) : super(key: key);

  final ReelsViewController _controller = ReelsViewController();

  @override
  ReelsViewController get controller => _controller;

  @override
  ReelsViewState createState() => ReelsViewState();

  @override
  Map<String, Function> setters() => {
        'currentIndex': (value) =>
            _controller.currentIndex = Utils.getInt(value, fallback: 0),
        'prefetchThreshold': (value) =>
            _controller.prefetchThreshold = Utils.optionalInt(value, min: 0),
        'preloadPages': (value) =>
            _controller.preloadPages = Utils.optionalInt(value, min: 0),
        'itemKeyField': (value) =>
            _controller.itemKeyField = Utils.optionalString(value),
        'onItemChange': (action) => _controller.onItemChange =
            EnsembleAction.from(action, initiator: this),
        'onEndReached': (action) => _controller.onEndReached =
            EnsembleAction.from(action, initiator: this),
      };

  @override
  Map<String, Function> getters() => {
        'currentIndex': () => _controller.currentIndex,
        'itemCount': () => _controller.itemCount,
      };

  @override
  Map<String, Function> methods() => {
        'next': () => _controller.next(),
        'previous': () => _controller.previous(),
        'animateToIndex': (int index) => _controller.animateToIndex(index),
        'retryEndReached': () => _controller.retryEndReached(),
      };

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    _controller.itemTemplate = ItemTemplate.from(itemTemplate);
  }
}

class ReelsViewController extends BoxController {
  ItemTemplate? itemTemplate;
  EnsembleAction? onItemChange;
  EnsembleAction? onEndReached;
  int? prefetchThreshold;
  int? preloadPages;
  String? itemKeyField;
  int currentIndex = 0;

  ReelsViewState? _state;

  int get itemCount => _state?.itemCount ?? 0;

  void next() => _state?.nextPage();

  void previous() => _state?.previousPage();

  void animateToIndex(int index) => _state?.animateToIndex(index);

  void retryEndReached() => _state?.retryEndReached();
}

class ReelsViewState extends EWidgetState<ReelsView> with TemplatedWidgetState {
  final PageController _pageController = PageController();

  List<dynamic> _data = const [];
  int _settledIndex = 0;
  bool _registered = false;
  bool _restored = false;
  bool _programmaticScroll = false;
  bool _endReachedArmed = true;

  int get itemCount => _data.length;

  @override
  void initState() {
    super.initState();
    widget._controller._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_registered || widget._controller.itemTemplate == null) return;
    _registered = true;
    registerItemTemplate(context, widget._controller.itemTemplate!,
        onDataChanged: _onDataChanged);
  }

  void _onDataChanged(List dataList) {
    if (!mounted) return;
    setState(() {
      _data = dataList;
    });
    _endReachedArmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  void _restorePosition() {
    if (!mounted || _data.isEmpty || !_pageController.hasClients) return;

    final target = widget._controller.currentIndex.clamp(0, _data.length - 1);
    if (!_restored) {
      _pageController.jumpToPage(target);
      _settledIndex = target;
      _restored = true;
      if (widget._controller.currentIndex != target) {
        widget._controller.currentIndex = target;
      }
      return;
    }

    if (target != _settledIndex && !_programmaticScroll) {
      _animateTo(target);
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    widget._controller._state = this;
    final template = widget._controller.itemTemplate;
    if (template == null) return const SizedBox.shrink();

    final preload = (widget._controller.preloadPages ?? 0) > 0;
    return BoxWrapper(
      boxController: widget._controller,
      widget: PageView.builder(
        controller: _pageController,
        physics: const PageScrollPhysics(),
        allowImplicitScrolling: preload,
        itemCount: _data.length,
        onPageChanged: _onPageChanged,
        scrollDirection: Axis.vertical,
        pageSnapping: true,
        itemBuilder: (context, index) {
          final item = buildWidgetForIndex(context, _data, template, index);
          return KeyedSubtree(
            key: ValueKey(_itemKey(index)),
            child: item ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  String _itemKey(int index) {
    final field = widget._controller.itemKeyField;
    if (field != null && index < _data.length) {
      final item = _data[index];
      if (item is Map && item[field] != null) return item[field].toString();
    }
    return 'index:$index';
  }

  void _onPageChanged(int index) {
    if (index == _settledIndex && _restored) return;
    _settledIndex = index;
    _restored = true;
    if (widget._controller.currentIndex != index) {
      widget._controller.currentIndex = index;
    }
    _executeOnItemChange(index);
    _checkEndReached(index);
  }

  void _executeOnItemChange(int index) {
    final action = widget._controller.onItemChange;
    if (action == null) return;
    ScreenController().executeAction(context, action);
  }

  void _checkEndReached(int index) {
    final action = widget._controller.onEndReached;
    if (action == null || _data.isEmpty) return;

    // prefetchThreshold is the number of items remaining, including the
    // current item. threshold: 3 fires at itemCount - 3.
    final threshold = widget._controller.prefetchThreshold ?? 2;
    final remaining = _data.length - index;
    if (remaining > threshold) {
      _endReachedArmed = true;
      return;
    }
    if (!_endReachedArmed) return;

    _endReachedArmed = false;
    ScreenController().executeAction(context, action);
  }

  void retryEndReached() {
    _endReachedArmed = true;
    _checkEndReached(_settledIndex);
  }

  void nextPage() {
    if (_data.isEmpty || !_pageController.hasClients) return;
    _animateTo((_settledIndex + 1).clamp(0, _data.length - 1));
  }

  void previousPage() {
    if (_data.isEmpty || !_pageController.hasClients) return;
    _animateTo((_settledIndex - 1).clamp(0, _data.length - 1));
  }

  void animateToIndex(int index) {
    if (_data.isEmpty || !_pageController.hasClients) return;
    _animateTo(index.clamp(0, _data.length - 1));
  }

  void _animateTo(int index) {
    if (index == _settledIndex || !_pageController.hasClients) return;

    _programmaticScroll = true;
    _pageController
        .animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    )
        .whenComplete(() {
      _programmaticScroll = false;
      if (mounted) _onPageChanged(index);
    });
  }

  @override
  void didUpdateWidget(covariant ReelsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_restored || _programmaticScroll) return;
    if (widget._controller.currentIndex != _settledIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restorePosition();
      });
    }
  }

  @override
  void dispose() {
    widget._controller._state = null;
    _pageController.dispose();
    super.dispose();
  }
}
