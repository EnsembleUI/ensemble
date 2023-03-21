import * as widgets from './widgetSchema';
import * as actions from './actionSchema';

export type App = {View: View} | {ViewGroup: ViewGroup};
export type RootWidget = widgets.Column | widgets.Row;

/* This is the root view */
export interface View extends widgets.HasChildren {
// 	menu?: {BottomNavBar: BottomNavBar} | {SideBar: SideBar};
}
export interface ViewGroup {

}










// export interface Screen {
//   ViewGroup?: ViewGroup;
//
// }
// export interface RootWidgets {
//   Column?: widgets.Column
// }
// export interface Widgets extends RootWidgets {
//   Row?:widgets.Row;
//   Text?:widgets.Text;
//
// }

//
// export interface ViewGroup extends RootWidgets {
//   menu?: {BottomNavBar: BottomNavBar} | {SideBar: SideBar}
//   header?: string | Widgets;
//
// }
//menu widgets
/**
 * Use the bottom navigation bar (default)
 */
export interface BottomNavBar {
  icon: string;
  iconLibrary?: string;
  label: string;
  page: string;
  selected: boolean;
//   onTap: actions.Action;
}
export interface SideBar {
  icon: string;
  iconLibrary?: string;
  label: string;
  page: string;
  selected: boolean;
//   onTap: actions.Action;
}



