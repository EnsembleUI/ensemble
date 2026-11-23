import 'package:ensemble/framework/tv/tv_focus_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// TV focus scrolling must give the same result whether or not the host app
/// scales its UI.
///
/// Every scenario runs twice on the same 960x540 layout:
/// - Android TV: a 960x540 screen, no scaling.
/// - Apple TV: a 1920x1080 screen where the host renders the 960x540 layout
///   and scales it up 2x with a FittedBox (what the KPN app does on tvOS).
///
/// Before the fix, Ensemble compared screen positions (which include the 2x)
/// with sizes and scroll offsets (which don't), so on Apple TV visible items
/// looked off-screen: the page jumped and lanes lost their leading margin.

const _designSize = Size(960, 540);

/// Content offset of the vertical page inside the screen (a top bar).
const double _topBar = 78;

/// Height of the hero section at the top of the page.
const double _heroHeight = 300;

/// The hero's focusable button, near the bottom of the hero.
const double _heroButtonTop = 266;
const double _heroButtonHeight = 34;

/// A row of focusable cards with a 48 px leading margin, like a Sports lane.
const double _laneTop = _heroHeight;
const double _laneHeight = 174;
const double _laneMargin = 48;
const double _cardWidth = 215;
const double _cardGap = 16;

/// Number of lanes; enough to make the page scroll.
const int _laneCount = 6;

class _Host {
  _Host({required this.name, required this.scale});
  final String name;
  final double scale;
}

final _hosts = [
  _Host(name: 'Android TV (1x)', scale: 1),
  _Host(name: 'Apple TV (2x host scale)', scale: 2),
];

class _Page {
  final page = ScrollController();
  final lanes = [for (var i = 0; i < _laneCount; i++) ScrollController()];
  final heroButton = GlobalKey();
  final cards = [
    for (var lane = 0; lane < _laneCount; lane++)
      [for (var i = 0; i < 12; i++) GlobalKey()],
  ];

  void dispose() {
    page.dispose();
    for (final c in lanes) {
      c.dispose();
    }
  }

  ScrollableState get pageScrollable =>
      Scrollable.of(heroButton.currentContext!);

  ScrollableState laneScrollable(int lane) =>
      Scrollable.of(cards[lane][0].currentContext!);

  RenderBox box(GlobalKey key) =>
      key.currentContext!.findRenderObject()! as RenderBox;
}

Future<_Page> _pumpPage(WidgetTester tester, _Host host) async {
  final page = _Page();
  addTearDown(page.dispose);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _designSize * host.scale;
  addTearDown(tester.view.reset);

  Widget content = Column(
    children: [
      const SizedBox(height: _topBar),
      Expanded(
        child: SingleChildScrollView(
          controller: page.page,
          child: Column(
            children: [
              SizedBox(
                height: _heroHeight,
                child: Stack(children: [
                  Positioned(
                    left: 51,
                    top: _heroButtonTop,
                    child: SizedBox(
                      key: page.heroButton,
                      width: 103,
                      height: _heroButtonHeight,
                    ),
                  ),
                ]),
              ),
              for (var lane = 0; lane < _laneCount; lane++)
                SizedBox(
                  height: _laneHeight,
                  child: ListView(
                    controller: page.lanes[lane],
                    scrollDirection: Axis.horizontal,
                    // Build every card, so off-screen ones have a size.
                    cacheExtent: 5000,
                    padding: const EdgeInsets.only(left: _laneMargin),
                    children: [
                      for (final key in page.cards[lane])
                        Padding(
                          padding: const EdgeInsets.only(right: _cardGap),
                          child: SizedBox(
                            key: key,
                            width: _cardWidth,
                            height: _laneHeight,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  if (host.scale != 1) {
    // The host's scaling, as in the KPN app on tvOS: the 960x540 layout is
    // stretched to fill the whole screen.
    content = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: _designSize.width,
          height: _designSize.height,
          child: content,
        ),
      ),
    );
  }

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: content)));
  if (host.scale != 1) {
    // Guard the harness itself: the layout must really be drawn at 2x.
    final hero = page.box(page.heroButton);
    expect(hero.localToGlobal(Offset.zero).dy,
        (_topBar + _heroButtonTop) * host.scale);
  }
  await tester.pump();
  return page;
}

double _cardContentLeft(int index) =>
    _laneMargin + index * (_cardWidth + _cardGap);

void main() {
  for (final host in _hosts) {
    group(host.name, () {
      testWidgets('rectInScrollable measures in the scrollable\'s own units',
          (tester) async {
        final page = await _pumpPage(tester, host);
        final scrollableBox =
            page.pageScrollable.context.findRenderObject()! as RenderBox;

        final rect = rectInScrollable(page.box(page.heroButton), scrollableBox);

        expect(rect.top, _heroButtonTop);
        expect(rect.height, _heroButtonHeight);
        expect(scrollableBox.size.height, _designSize.height - _topBar);
      });

      group('page (vertical)', () {
        testWidgets('a visible hero button does not scroll the page',
            (tester) async {
          // The Sports bug: focus on the hero made the page jump down.
          final page = await _pumpPage(tester, host);

          scrollVerticalOnly(page.pageScrollable, page.box(page.heroButton),
              verticalPadding: 400);
          await tester.pumpAndSettle();

          expect(page.page.offset, 0);
        });

        testWidgets('an item below the viewport scrolls it into view',
            (tester) async {
          final page = await _pumpPage(tester, host);
          const lane = 3;
          const padding = 50.0;

          scrollVerticalOnly(page.pageScrollable, page.box(page.cards[lane][0]),
              verticalPadding: padding);
          await tester.pumpAndSettle();

          // Card bottom ends `padding` above the viewport bottom.
          const cardBottom = _laneTop + (lane + 1) * _laneHeight;
          const viewport = 540 - _topBar;
          expect(page.page.offset,
              closeTo(cardBottom - (viewport - padding), 0.5));
        });

        testWidgets('an item above the viewport scrolls back up',
            (tester) async {
          final page = await _pumpPage(tester, host);
          page.page.jumpTo(600);
          await tester.pump();
          const padding = 50.0;

          scrollVerticalOnly(page.pageScrollable, page.box(page.cards[0][0]),
              verticalPadding: padding);
          await tester.pumpAndSettle();

          // Card top lands `padding` below the viewport top.
          expect(page.page.offset, closeTo(_laneTop - padding, 0.5));
        });

        testWidgets('carousel-style refocus does not bounce the page',
            (tester) async {
          // The Sports bug: each autoplay slide re-focused the hero and the
          // page jumped 0 -> 504 -> 0 -> 504.
          final page = await _pumpPage(tester, host);

          for (var slide = 0; slide < 4; slide++) {
            scrollVerticalOnly(page.pageScrollable, page.box(page.heroButton),
                verticalPadding: 400);
            await tester.pumpAndSettle();
            expect(page.page.offset, 0, reason: 'slide $slide');
          }
        });

        testWidgets('ensureWidgetVisible leaves a visible item alone',
            (tester) async {
          final page = await _pumpPage(tester, host);

          await ensureWidgetVisible(page.heroButton.currentContext!);
          await tester.pumpAndSettle();

          expect(page.page.offset, 0);
          expect(page.lanes[0].offset, 0);
        });

        testWidgets('ensureWidgetVisible reveals an item below the viewport',
            (tester) async {
          final page = await _pumpPage(tester, host);
          const lane = 3;

          await ensureWidgetVisible(page.cards[lane][0].currentContext!);
          await tester.pumpAndSettle();

          // keepVisibleAtEnd: card bottom at the viewport bottom.
          const cardBottom = _laneTop + (lane + 1) * _laneHeight;
          expect(page.page.offset, closeTo(cardBottom - (540 - _topBar), 0.5));
        });
      });

      group('lane (horizontal, fixed focus position)', () {
        testWidgets('the first card keeps the lane\'s leading margin',
            (tester) async {
          // The Sports bug: the first card looked 96 px in, so the lane
          // scrolled 48 px and the card touched the left edge.
          final page = await _pumpPage(tester, host);

          scrollHorizontalWithFixedPosition(
              page.laneScrollable(0), page.box(page.cards[0][0]), _laneMargin);
          await tester.pumpAndSettle();

          expect(page.lanes[0].offset, 0);
        });

        testWidgets('a later card is scrolled to the fixed position',
            (tester) async {
          final page = await _pumpPage(tester, host);
          const card = 5;

          scrollHorizontalWithFixedPosition(page.laneScrollable(0),
              page.box(page.cards[0][card]), _laneMargin);
          await tester.pumpAndSettle();

          expect(page.lanes[0].offset,
              closeTo(_cardContentLeft(card) - _laneMargin, 0.5));
        });

        testWidgets('moving right card by card keeps focus at the margin',
            (tester) async {
          final page = await _pumpPage(tester, host);

          for (var card = 1; card <= 4; card++) {
            scrollHorizontalWithFixedPosition(page.laneScrollable(0),
                page.box(page.cards[0][card]), _laneMargin);
            await tester.pumpAndSettle();
            final left = rectInScrollable(
                    page.box(page.cards[0][card]),
                    page.laneScrollable(0).context.findRenderObject()!
                        as RenderBox)
                .left;
            expect(left, closeTo(_laneMargin, 0.5), reason: 'card $card');
          }
        });
      });

      group('lane (horizontal, default centring)', () {
        testWidgets('a fully visible card does not scroll the lane',
            (tester) async {
          final page = await _pumpPage(tester, host);

          scrollHorizontalIfNotVisible(
              page.laneScrollable(0), page.box(page.cards[0][1]));
          await tester.pumpAndSettle();

          expect(page.lanes[0].offset, 0);
        });

        testWidgets('an off-screen card is centred', (tester) async {
          final page = await _pumpPage(tester, host);
          const card = 6;

          scrollHorizontalIfNotVisible(
              page.laneScrollable(0), page.box(page.cards[0][card]));
          await tester.pumpAndSettle();

          final cardCenter = _cardContentLeft(card) + _cardWidth / 2;
          expect(page.lanes[0].offset,
              closeTo(cardCenter - _designSize.width / 2, 0.5));
        });
      });
    });
  }
}
