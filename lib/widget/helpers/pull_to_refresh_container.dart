import 'dart:developer';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:ensemble/model/pull_to_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// a wrapper around a scrollable widget to support pull to refresh
class PullToRefreshContainer extends StatefulWidget {
  const PullToRefreshContainer(
      {super.key,
      required this.contentWidget,
      this.refreshWidget,
      this.options,
      required this.onRefresh});

  final Widget contentWidget;
  final Future<void> Function() onRefresh;

  // TODO: size the refresh widget properly before expose it.
  final Widget? refreshWidget;
  final PullToRefreshOptions? options;

  @override
  State<PullToRefreshContainer> createState() => _PullToRefreshContainerState();
}

class _PullToRefreshContainerState extends State<PullToRefreshContainer> {
  static const double _defaultIndicatorSize = 30;

  @override
  Widget build(BuildContext context) {
    double totalIndicatorHeight = _defaultIndicatorSize +
        (widget.options?.indicatorPadding != null
            ? widget.options!.indicatorPadding!.top +
                widget.options!.indicatorPadding!.bottom
            : 0);

    return CustomRefreshIndicator(
        offsetToArmed:
            totalIndicatorHeight / 2, // tweak this number or expose it
        onRefresh: processOnRefresh,
        builder: (context, child, controller) => Stack(
              children: [
                if (!controller.isIdle && !controller.isCanceling)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(),
                          child: _getRefreshWidget(controller))
                    ],
                  ),

                // this is the content widget (which slides down as the progress widget appears)
                Transform.translate(
                    offset: Offset(0, totalIndicatorHeight * controller.value),
                    child: child)
              ],
            ),
        child: widget.contentWidget);
  }

  Widget _getRefreshWidget(IndicatorController controller) {
    Widget rtn = widget.refreshWidget ??
        SizedBox(
            width: _defaultIndicatorSize,
            height: _defaultIndicatorSize,
            child: _getProgressIndicator(controller));
    if (widget.options?.indicatorPadding != null) {
      rtn = Padding(padding: widget.options!.indicatorPadding!, child: rtn);
    }
    return rtn;
  }

  Widget _getProgressIndicator(IndicatorController controller) {
    if (widget.options?.indicatorType == RefreshIndicatorType.cupertino) {
      return controller.isDragging || controller.isArmed
          ? CupertinoActivityIndicator.partiallyRevealed(
              progress: controller.value.clamp(0, 1),
              radius: _defaultIndicatorSize / 2)
          : const CupertinoActivityIndicator(radius: _defaultIndicatorSize / 2);
    } else {
      // default to Material theme
      return CircularProgressIndicator(
          value: controller.isDragging || controller.isArmed
              ? controller.value.clamp(0, 1)
              : null);
    }
  }

  Future<void> processOnRefresh() async {
    final stopwatch = Stopwatch()..start();
    await widget.onRefresh();
    stopwatch.stop();

    // ensure we run the minimum duration specified
    if (widget.options?.indicatorMinDuration != null &&
        widget.options!.indicatorMinDuration!.compareTo(stopwatch.elapsed) >
            0) {
      int additionalMs = widget.options!.indicatorMinDuration!.inMilliseconds -
          stopwatch.elapsedMilliseconds;

      return Future.delayed(Duration(milliseconds: additionalMs));
    }
  }
}
