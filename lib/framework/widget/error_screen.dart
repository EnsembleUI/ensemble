import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ErrorScreen extends StatelessWidget {
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

      return ErrorScreen._init(
        myError.error,
        recovery: myError.recovery,
        detailError: join(myError.detailError, stackTrace?.toString())
      );
    } else if (myError is Error) {
      return ErrorScreen._init(
          myError.toString(),
          detailError: join(myError.stackTrace?.toString(), stackTrace?.toString())
      );
    }
    return ErrorScreen._init(
      "Unknown Error occurred.",
      detailError: stackTrace?.toString(),
    );
  }

  final String errorText;
  final String? recovery;
  final String? detailError;

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    // main error and graphics
    children.add(Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          Utils.randomize(["Oh Snap", "Uh Oh ..", "Foo Bar"]),
          style: const TextStyle(fontSize: 28, color: Color(0xFFF7535A), fontWeight: FontWeight.w500)
        ),
        const Image(
          image: AssetImage("assets/images/error.png"),
          width: 200
        ),
        const SizedBox(height: 16),
        Text(
          errorText + (recovery != null ? '\n$recovery' : ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
      ],
    ));

    // add detail
    if (detailError != null && kDebugMode) {
      children.add(Column(
          children: [
            const SizedBox(height: 30),
            const Text(
                'DETAILS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
            ),
            const SizedBox(height: 10),
            Text(
                detailError!,
                textAlign: TextAlign.start,
                style: const TextStyle(fontSize: 14, color: Colors.black87)
            )
          ]
        )
      );
    }


    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 40, right: 40, top: 40),
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children
            ),
          )
        )
      )
    );
  }

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

}