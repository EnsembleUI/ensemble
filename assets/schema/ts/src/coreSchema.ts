import * as widgets from "./widgetSchema";
import * as widgetsDef from "./widgets";
import { Menu } from "./widgets";
import { API, Functions, GlobalType, View } from "./widgetSchema";
import { Action } from "./actionSchema";

// /**
//  * @additionalProperties true
//  * */
// export interface Screen {
//   ViewGroup?: ViewGroup;
// }

export interface RootWidgets {
  Column?: widgets.Column;
  Flow?: widgets.Flow;
  Flex?: widgets.Flex;
  Stack?: widgets.Stack;
  ListView?: widgets.ListView;
  Carousel?: widgets.Carousel;
  FittedColumn?: widgets.FittedBoxLayout;
  FittedRow?: widgets.FittedBoxLayout;
}
export interface Widgets extends RootWidgets {
  Row?: widgets.Row;
  Text?: widgetsDef.Text;
  Markdown?: widgetsDef.Markdown;
  Image?: widgetsDef.Image;
  Lottie?: widgetsDef.Lottie;
  Icon?: widgetsDef.Icon;
  Button?: widgetsDef.Button;
  Date?: widgetsDef.Date;
  Divider?: widgetsDef.Divider;
  Html?: widgetsDef.Html;
  OnOff?: widgetsDef.OnOff;
  PasswordInput?: widgetsDef.PasswordInput;
  TextInput?: widgetsDef.TextInput;
  Progress?: widgetsDef.Progress;
  QRCode?: widgetsDef.QRCode;
  SelectOne?: widgetsDef.SelectOne;
  Spacer?: widgetsDef.Spacer;
  Time?: widgetsDef.Time;
  TabBar?: widgetsDef.TabBar;
  GridView?: widgetsDef.GridView;
  Form?: widgetsDef.Form;
  Map?: widgetsDef.Menu;
  ChartJS?: widgetsDef.ChartJS;
  Video?: widgetsDef.Video;
  WebView?: widgetsDef.WebView;
}
export interface ItemTemplate {
  data: string;
  name: string;
  template: Widgets | string;
}
export interface TemplatedWidget {
  "item-template"?: ItemTemplate;
}

/**
 * Group multiple Views together and put them behind a menu.
 * */
export type ViewGroup = Menu;
/**
 * @additionalProperties true
 * */
export interface AdditionalProperties {
  /**
   * Specify a widget to render.
   * */
  body: Widgets;
  /**
   * Define the list of input names that this Custom Widget accepts.
   * */
  inputs?: [];
  /**
   * Execute an Action when this Custom Widget loads
   * */
  onLoad?: Action;
}

/**
 * @additionalProperties true
 * */
export type properties = {
  Import?: {};
  ViewGroup?: Menu;
  View?: View;
  Action?: {};
  Model?: {};
  App?: {};
  Variable?: {};
  Functions?: Functions;
  Global?: GlobalType;
  API?: API;
} & {
  /**
   * Defining a Custom Widget
   * */
  [key: string]: AdditionalProperties;
};
