import 'package:flutter/material.dart';

class OtpKeyboard extends StatelessWidget {
  OtpKeyboard(
      {super.key,
      required this.callbackValue,
      required this.callbackSubmitValue,
      required this.callbackDeleteValue});

  final Function(String) callbackValue;
  final VoidCallback callbackDeleteValue;
  final VoidCallback callbackSubmitValue;
  final FocusNode myFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return CustomKeyboard(
      onTextInput: (myText) => callbackValue(myText),
      onBackspace: () => callbackDeleteValue(),
      onSubmit: () => callbackSubmitValue(),
    );
  }

  void dispose() {
    myFocusNode.dispose();
  }
}

class CustomKeyboard extends StatelessWidget {
  const CustomKeyboard({
    Key? key,
    required this.onTextInput,
    required this.onBackspace,
    required this.onSubmit,
  }) : super(key: key);

  final ValueSetter<String> onTextInput;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  void _textInputHandler(String text) => onTextInput.call(text);

  void _backspaceHandler() => onBackspace.call();
  void _onSubmitHandler() => onSubmit.call();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        child: Container(
          // height: 280,
          // margin:const EdgeInsets.only(bottom: 30) ,
          decoration: BoxDecoration(
              color: const Color(0xffEDEDED).withValues(alpha: 0.4),
              //  border: Border.all(  color: Colors.grey.withValues(alpha: 0.4),),
              borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              buildRowOne(),
              buildRowTwo(),
              buildRowThree(),
              buildRowFour(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildRowOne() {
    return Row(
      children: [
        TextKey(text: '1', onTextInput: _textInputHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        TextKey(text: '2', onTextInput: _textInputHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        TextKey(text: '3', onTextInput: _textInputHandler),
      ],
    );
  }

  Widget buildRowTwo() {
    return Row(
      children: [
        TextKey(text: '4', onTextInput: _textInputHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        TextKey(text: '5', onTextInput: _textInputHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        TextKey(text: '6', onTextInput: _textInputHandler),
      ],
    );
  }

  Widget buildRowThree() {
    return Row(
      children: [
        TextKey(text: '7', onTextInput: _textInputHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        TextKey(text: '8', onTextInput: _textInputHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        TextKey(text: '9', onTextInput: _textInputHandler),
      ],
    );
  }

  Widget buildRowFour() {
    return Row(
      children: [
        BackspaceKey(onBackspace: _backspaceHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        TextKey(text: '0', onTextInput: _textInputHandler),
        Container(
          width: 1,
          height: 60,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        CheckKey(onCheck: _onSubmitHandler)
      ],
    );
  }
}

class TextKey extends StatelessWidget {
  const TextKey({
    Key? key,
    required this.text,
    required this.onTextInput,
    this.flex = 1,
  }) : super(key: key);

  final String text;
  final ValueSetter<String> onTextInput;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            onTextInput.call(text);
          },
          child: Center(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          )),
        ),
      ),
    );
  }
}

class BackspaceKey extends StatelessWidget {
  const BackspaceKey({
    Key? key,
    required this.onBackspace,
    this.flex = 1,
  }) : super(key: key);

  final VoidCallback onBackspace;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            onBackspace.call();
          },
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: Icon(
                Icons.backspace_outlined,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CheckKey extends StatelessWidget {
  const CheckKey({
    Key? key,
    required this.onCheck,
  }) : super(key: key);

  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            onCheck.call();
          },
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: Icon(
                Icons.check,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
