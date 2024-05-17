import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class Rating extends StatefulWidget
    with Invokable, HasController<RatingController, RatingState> {
  static const type = 'Rating';
  Rating({Key? key}) : super(key: key);

  final RatingController _controller = RatingController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => RatingState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.value = Utils.optionalDouble(value),
      'count': (value) => _controller.count = Utils.optionalInt(value),
      'display': (value) => _controller.display = Utils.optionalString(value),
      'padding': (value) => _controller.padding = Utils.getInsets(value)
    };
  }
}

class RatingController extends WidgetController {
  double? value;
  int? count;
  String? display;
  EdgeInsets? padding;
}

class RatingState extends WidgetState<Rating> {
  late Color primaryColor;

  @override
  Widget buildWidget(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    primaryColor = themeData.colorScheme.primary;

    Widget? ratingWidget;
    if (widget._controller.display == 'full') {
      ratingWidget = Row(
        children: <Widget>[
          RatingBar(
            initialRating: (widget._controller.value ?? 0).toDouble(),
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 24,
            ratingWidget: RatingWidget(
              full: Icon(
                Icons.star_rate_rounded,
                color: primaryColor,
              ),
              half: Icon(
                Icons.star_half_rounded,
                color: primaryColor,
              ),
              empty: Icon(
                Icons.star_border_rounded,
                color: primaryColor,
              ),
            ),
            itemPadding: EdgeInsets.zero,
            onRatingUpdate: (rating) {},
          ),
          Text(
            widget._controller.count == 0
                ? ''
                : '${widget._controller.count} Reviews',
            style: TextStyle(fontSize: 14, color: Colors.grey.withOpacity(0.8)),
          ),
        ],
      );
    } else {
      ratingWidget = Container(
        child: Row(
          children: <Widget>[
            Text(
              widget._controller.value?.toString() ?? '',
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.w200,
                fontSize: 22,
                letterSpacing: 0.27,
                color: EnsembleTheme.grey,
              ),
            ),
            Icon(
              Icons.star,
              color: primaryColor,
              size: 24,
            ),
          ],
        ),
      );
    }

    if (widget._controller.padding != null) {
      return Padding(
        padding: widget._controller.padding!,
        child: ratingWidget,
      );
    }
    return ratingWidget;
  }
}
