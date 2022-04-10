import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RatingBuilder extends ensemble.WidgetBuilder {
  static const type = 'Rating';
  RatingBuilder({
    this.value,
    this.count,
    this.display,
    styles
  }): super(styles: styles);
  double? value;
  int? count;
  String? display;

  static RatingBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return RatingBuilder(
      value: props['value'] ?? 0,
      count: props['count'] ?? 0,
      display: props['display'],

      // styles
      styles: styles
    );
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return Rating(builder: this);
  }

}

class Rating extends StatefulWidget {
  const Rating({
    required this.builder,
    Key? key
  }) : super(key: key);

  final RatingBuilder builder;

  @override
  State<StatefulWidget> createState() => RatingState();
}

class RatingState extends State<Rating> {
  @override
  Widget build(BuildContext context) {
    Widget? ratingWidget;
    if (widget.builder.display == 'full') {
      ratingWidget = Row(
        children: <Widget>[
          RatingBar(
            initialRating: (widget.builder.value ?? 0).toDouble(),
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 24,
            ratingWidget: RatingWidget(
              full: const Icon(
                Icons.star_rate_rounded,
                color: Colors.blue,
              ),
              half: const Icon(
                Icons.star_half_rounded,
                color: Colors.blue,
              ),
              empty: const Icon(
                Icons
                    .star_border_rounded,
                color: Colors.blue,
              ),
            ),
            itemPadding:
            EdgeInsets.zero,
            onRatingUpdate: (rating) {
              print(rating);
            },
          ),
          Text(
            widget.builder.count == 0 ? '' : '${widget.builder.count} Reviews',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey
                    .withOpacity(0.8)),
          ),
        ],
      );
    } else {
      ratingWidget = Container(
        child: Row(
          children: <Widget>[
            Text(
              widget.builder.value?.toString() ?? '',
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.w200,
                fontSize: 22,
                letterSpacing: 0.27,
                color: EnsembleTheme.grey,
              ),
            ),
            const Icon(
              Icons.star,
              color: EnsembleTheme.nearlyBlue,
              size: 24,
            ),
          ],
        ),
      );
    }


    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      child: ratingWidget
    );


  }


}