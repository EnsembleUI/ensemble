import { HasIcon } from "./BoxStyles";
import { Action } from "../actionSchema";
import { BaseStyles } from "./baseStyles";

type integer = number;

enum generalColors {
  black = "black",
  red = "red",
  green = "green",
}

export enum directionEnum {
  vertical = "vertical",
  horizontal = "horizontal",
}

export enum screenType {
  regular = "regular",
  modal = "modal",
}

export enum navIconPosition {
  start = "start",
  end = "end",
}

export enum httpMethod {
  GET = "GET",
  PUT = "PUT",
  POST = "POST",
  PATCH = "PATCH",
  DELETE = "DELETE",
}

/**
 * Specify the action key on native device's soft keyboard
 * */
export enum keyboardAction {
  done = "done",
  go = "go",
  search = "search",
  send = "send",
  next = "next",
  previous = "previous",
}

export enum iconLibrary {
  default = "default",
  fontAwesome = "fontAwesome",
}

enum axisPosition {}

enum styleSelection {
  default = "default",
  none = "none",
}

enum decoration {
  none = "none",
  lineThrough = "lineThrough",
  underline = "underline",
  overline = "overline",
}

enum inputVariant {
  underline = "underline",
  box = "box",
}

/**
 * @pattern ^0x
 */
type colorPattern = string;

export enum fontWeight {
  light = "light",
  normal = "normal",
  bold = "bold",
  w100 = "w100",
  w200 = "w200",
  w300 = "w300",
  w400 = "w400",
  w500 = "w500",
  w600 = "w600",
  w700 = "w700",
  w800 = "w800",
  w900 = "w900",
}

enum fontName {
  heading = "heading",
  title = "title",
  subtitle = "subtitle",
}

enum overflow {
  wrap = "wrap",
  visible = "visible",
  clip = "clip",
  ellipsis = "ellipsis",
}

enum textAlign {
  start = "start",
  end = "end",
  center = "center",
  justify = "justify",
}

enum textStyle {
  normal = "normal",
  italic = "italic",
  underline = "underline",
  strikethrough = "strikethrough",
  italic_underline = "italic_underline",
  italic_strikethrough = "italic_strikethrough",
}

enum toastPosition {
  top = "top",
  topLeft = "topLeft",
  topRight = "topRight",
  center = "center",
  centerLeft = "centerLeft",
  centerRight = "centerRight",
  bottom = "bottom",
  bottomLeft = "bottomLeft",
  bottomRight = "bottomRight",
}

enum lineHeight {
  default = "default",
  "1.0" = "1.0",
  _1_15 = "1.15",
  _1_25 = "1.25",
  _1_5 = "1.5",
  _2_0 = "2.0",
  _2_5 = "2.5",
}

enum toastStyle {
  success = "success",
  error = "error",
  warning = "warning",
  info = "info",
}

export interface ContainerStyles {}

export type styleText = {
  fontSize?: integer;
  color?: Colors;
  decoration?: decoration;
};

export interface DialogOptions {
  /**
   * @minimum 0
   * */
  minWidth?: integer;
  maxWidth?: integer;
  /**
   * @minimum 0
   * */
  minHeight?: integer;
  maxHeight?: integer;
  /**
   * Offset the dialog's position horizontally, with -1.0 for the screen's left and 1.0 for the screen's right.
   * (default is 0 for centering horizontally)
   * @minimum -1
   * @maximum 1
   * */
  horizontalOffset?: number;
  /**
   * Offset the dialog's position vertically, with -1.0 for the screen's top and 1.0 for the screen's bottom.
   * (default is 0 for centering vertically)
   * @minimum -1
   * @maximum 1
   * */
  verticalOffset?: number;
  /*
   * Render the dialog with a default style. You can also specify 'none' and control your own styles in your widget.
   * */
  style?: styleSelection;
}

export interface TimerOptions {
  /*
   * Marking this timer as global will ensure the timer, if repeating indefinitely, will continue to run even if the
   * user navigates away from the screen, until explicitly stopped by the stopTimer action. Note that there can only
   *  ever be one global timer. Creating a new global timer will automatically cancel the previous global timer.
   * */
  isGlobal?: boolean;
  /**
   * Delay the timer's start by this number of seconds. If not specified and repeat is true, repeatInterval will be
   * used. If none is specified, there will be no initial delay
   * @minimum 0
   * */
  startAfter?: integer;
  /*
   * Whether the time should repeat and trigger at every repeatInterval seconds. This Timer will run continuously unless
   * a maxNumberOfTimes is specified
   * */
  repeat?: boolean;
  /**
   * Trigger the timer periodically at this repeatInterval (in seconds)
   * @minimum 1
   * */
  repeatInterval?: integer;
  /**
   * Set the max number of times the timer will triggers, if repeat is true
   * @minimum 1
   * */
  maxNumberOfTimes?: integer;
}

export interface ShowToastOptions {
  /*
   * Select a built-in toast style.
   * */
  type?: toastStyle;
  /*
   * Whether to show a dismiss button (default is True)
   * */
  dismissible?: boolean;
  position?: toastPosition;
  /**
   * The number of seconds after the toast is dismissed
   * @minimum 1
   * */
  duration?: integer;
}

export interface TextStyles {
  /**
   * Default built-in style for this text
   */
  font: fontName;
  /**
   * @minimum 6
   */
  fontSize: number;
  fontWeight: fontWeight;
  color: Colors;
  /**
   * Set treatment of text longer than available space
   */
  overflow: overflow;
  textAlign: textAlign;
  textStyle: textStyle;
  lineHeight: lineHeight;
}

export interface FormInput {
  /**
   * ID to be referenced later
   * */
  id?: string;
  /**
   * The max width of this Input widget (default 700)
   * @minimum 0
   * @maximum 5000
   * */
  maxWidth?: integer;
  /**
   * Label for your widget
   * */
  label?: string;
  /**
   * Hint text on your label
   * */
  labelHint?: string;
  /**
   * Hint text explaining your widget
   * */
  hintText?: string;
  required?: boolean;
  enabled?: boolean;
  /**
   * The icon to show before the Input field
   * */
  icon?: HasIcon;
  /**
   * Call Ensemble's built-in functions or execute code when the input changes. Note for free-form text input,
   * this event only dispatches if the text changes AND the focus is lost (e.g. clicking on button)
   * */
  onChange?: Action;
  styles?: BaseStyles & {
    /**
     * Select a pre-defined look and feel for this Input widget. This property can be defined in the theme to apply
     * to all Input widgets.
     * */
    variant?: inputVariant;
    /**
     * Padding around your input content with CSS-style notation e.g. margin: 5 20 5
     * */
    contentPadding?: integer | string;
    /**
     * The fill color for this input fields. This property can be defined in the theme to apply to all Input widgets.
     * */
    fillColor?: Colors;
    /**
     * The border radius for this Input widget. This property can be defined in the theme to apply to all Input widgets.
     * @minimum 0
     * */
    borderRadius?: integer;
    /**
     * The border width for this Input widget. This property can be defined in the theme to apply to all Input widgets.
     * @minimum 0
     * */
    borderWidth?: integer;
    /**
     * The base border color for this input widget. This border color determines the look and feel of your input, while
     * the other colors are overrides for different states. This property can be defined in the theme to apply to all
     * Input widgets.
     * */
    borderColor?: Colors;
    /**
     * The border color for this input field if enabled. This property can be defined in the theme to apply to all
     * Input widgets.
     * */
    enabledBorderColor?: Colors;
    /**
     * The border color for this input field if disabled. This property can be defined in the theme to apply to all
     * Input widgets.
     * */
    disabledBorderColor?: Colors;
    /**
     * The border color  when there are errors on this input field. This property can be defined in the theme to apply
     * to all Input widgets.
     * */
    errorBorderColor?: Colors;
    /**
     * The border color when this input field is receiving focus. This property can be defined in the theme to apply
     * to all Input widgets.
     * */
    focusedBorderColor?: Colors;
    /*
     * The border color of this input field when it is receiving focus in its error state. This property can be
     *  defined in the theme to apply to all Input widgets.
     * */
    focusedErrorBorderColor?: Colors;
    /**
     * @minimum 6
     * */
    fontSize?: number;
  };
}

export interface inputValidator {
  validator?: {
    /**
     * The minimum number of characters
     * @minimum 0
     * */
    minLength?: integer;
    /**
     * The maximum number of characters
     * @minimum 0
     * */
    maxLength?: integer;
    /**
     * The Regular Expression the input will need to match
     * */
    regex?: string;
    /**
     * The customized error message to show when the input does not match the provided regex.
     * */
    regexError?: string;
  };
}

/**
 * @default "black"
 * */
export type Colors = number | generalColors | colorPattern;
