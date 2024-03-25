import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ErrorScreen extends StatefulWidget {
  const ErrorScreen._init(this.errorText, {this.recovery, this.detailError});

  factory ErrorScreen(Object error, {Key? key}) {
    Object myError = error;
    StackTrace? stackTrace;
    if (error is FlutterErrorDetails) {
      myError = error.exception;
      stackTrace = error.stack;
    }

    // process the error
    if (myError is EnsembleError) {
      List<String> detail = [];
      if (myError.detailError != null) {
        detail.add(myError.detailError!);
      }

      return ErrorScreen._init(myError.error,
          recovery: myError.recovery,
          detailError: join(myError.detailError, stackTrace?.toString()));
    } else if (myError is Error) {
      return ErrorScreen._init(myError.toString(),
          detailError:
              join(myError.stackTrace?.toString(), stackTrace?.toString()));
    }
    return ErrorScreen._init(
      "Unknown Error occurred.",
      detailError: stackTrace?.toString(),
    );
  }

  final String errorText;
  final String? recovery;
  final String? detailError;

  static String join(String? first, String? second) {
    List<String> list = [];
    if (first != null) {
      list.add(first);
    }
    if (second != null) {
      list.add(second);
    }
    return list.join('\n');
  }

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  OverlayEntry? overlayEntry;
  int currentPageIndex = 0;

  void createErrorOverlay() {
    // Remove the existing OverlayEntry.
    removeErrorOverlay();
    assert(overlayEntry == null);

    overlayEntry = OverlayEntry(
        // Create a new OverlayEntry.
        builder: (BuildContext context) {
      // Studio gets debug info even though it is compiled as release mode
      if (!kReleaseMode || StudioDebugger().debugMode) {
        return _debugErrorWidget();
      }
      return _releaseErrorWidget();
    });

    // Add the OverlayEntry to the Overlay.
    Overlay.of(context, debugRequiredFor: widget).insert(overlayEntry!);
  }

  // Remove the OverlayEntry.
  void removeErrorOverlay() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  /// return this widget in release mode
  Widget _releaseErrorWidget() {
    return Scaffold(
        body: Center(

            /// attempt to first load /ensemble/assets/error.png from Starter repo.
            /// This is how customers can customize a primitive error image.
            /// If the image is not found, fallback to our default
            child: Image.asset('ensemble/assets/error.png',
                errorBuilder: (context, error, stackTrace) =>
                    _releaseDefaultErrorWidget())));
  }

  Widget _releaseDefaultErrorWidget() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image(
            image: AssetImage("assets/images/error.png", package: 'ensemble'),
            width: 200),
        Text(
          "Oops. Something's wrong.",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
        ),
        Text(
          "Please close and restart the app to continue",
          style: TextStyle(fontSize: 18),
        ),
        SizedBox(height: 50)
      ],
    );
  }

  /// use this error widget in debug mode
  Widget _debugErrorWidget() {
    List<Widget> children = [];

    // main error and graphics
    children.add(Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(Utils.randomize(["Oh Snap", "Uh Oh ..", "Foo Bar"]),
            style: const TextStyle(
                fontSize: 28,
                color: Color(0xFFF7535A),
                fontWeight: FontWeight.w500)),
        const Image(
            image: AssetImage("assets/images/error.png", package: 'ensemble'),
            width: 200),
        const SizedBox(height: 16),
        Text(
          widget.errorText +
              (widget.recovery != null ? '\n${widget.recovery}' : ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
      ],
    ));

    // add detail
    if (widget.detailError != null && kDebugMode) {
      children.add(Column(children: [
        const SizedBox(height: 30),
        const Text('DETAILS',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(widget.detailError!,
            textAlign: TextAlign.start,
            style: const TextStyle(fontSize: 14, color: Colors.black87))
      ]));
    }

    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 40, right: 40, top: 40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children))));
  }

  @override
  void dispose() {
    // Make sure to remove OverlayEntry when the widget is disposed.
    removeErrorOverlay();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => createErrorOverlay());
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
