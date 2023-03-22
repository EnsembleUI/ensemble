import { Widget } from "../widgetSchema";
import { Colors, fontWeight, HasIcon, styleMargin } from "../styles";
import { Widgets } from "../coreSchema";

type tabItemType = {
  /**
   * Setting the tab label
   * */
  label: string;
  icon?: HasIcon;
  /**
   * Return an inline widget or specify a custom widget to be rendered as this tab's content
   * */
  widget: Widgets;
};
enum tabPosition {
  start = "start",
  stretch = "stretch",
}
export interface TabBar extends Widget {
  /**
   * Selecting a Tab based on its index order
   * @minimum 0
   * */
  selectedIndex?: number;
  /**
   * Define each of your Tab here
   * */
  items?: tabItemType[];
  styles?: styleMargin & {
    /**
     * How to lay out the Tab labels
     * */
    tabPosition?: tabPosition;
    /**
     * Padding for each tab labels with CSS-style value. Default: 0 30 0 0 (right padding only)
     * */
    tabPadding?: string | number;
    /**
     * Font size for the tab text
     * */
    tabFontSize?: number;
    /**
     * Font weight for the tab text
     * */
    tabFontWeight?: fontWeight;
    /**
     * The background color of the tab's navigation bar
     * */
    tabBackgroundColor?: Colors;
    /**
     * The color of the selected tab's text
     * */
    activeTabColor?: Colors;
    /**
     * The color of the un-selected tabs' text
     * */
    inactiveTabColor?: Colors;
    /**
     * The color of the selected tab's indicator
     * */
    indicatorColor?: Colors;
    /**
     * The thickness of the selected tab's indicator
     * */
    indicatorThickness?: number;
  };
}
