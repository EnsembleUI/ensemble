import {
  MenuBase,
  MenuWithAdditionalStyles,
  MenuWithHeaderAndFooter,
} from "../styles";

/**
 * Use the bottom navigation bar
 * */
type BottomNavBar = MenuBase;

/**
 * Put the menu behind a drawer icon on the header. The drawer icon will be positioned to the 'start' of the header
 * (left for most languages, right for RTL languages).
 * */
type Drawer = MenuWithHeaderAndFooter;

/**
 * Put the menu behind a drawer icon on the header. The drawer icon will be positioned to the 'end' of the header
 * (right for most languages, left for RTL languages).
 * */
type EndDrawer = MenuWithHeaderAndFooter;

/**
 * Enable a fixed navigation menu to the 'start' of the screen (left for most languages, right for RTL languages).
 * The menu may become a drawer menu on lower resolution.
 * */
type Sidebar = MenuWithAdditionalStyles;

/**
 * Enable a fixed navigation menu to the 'end' of the screen (right for most languages, left for RTL languages).
 * The menu may become a drawer menu on lower resolution.
 * */
type EndSidebar = MenuWithAdditionalStyles;

/**
 * Specify the navigation menu for this page
 * */
export type Menu =
  | { BottomNavBar: BottomNavBar }
  | { Drawer: Drawer }
  | { EndDrawer: EndDrawer }
  | { Sidebar: Sidebar }
  | { EndSidebar: EndSidebar };
