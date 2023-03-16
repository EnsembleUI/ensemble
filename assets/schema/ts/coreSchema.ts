import * as widgets from './widgetSchema';
import * as actions from './actionSchema';

export interface Screen {
  ViewGroup?: ViewGroup;

}
export interface RootWidgets {
  Column?: widgets.Column
}
export interface Widgets extends RootWidgets {
  Row?:widgets.Row;
  Text?:widgets.Text;
  
}
export interface ItemTemplate {
  data: string;
  name: string;
  template: Widgets | string;
}
export interface TemplatedWidget {
  "item-template"?: ItemTemplate;
}

export interface ViewGroup extends RootWidgets {
  menu?: {BottomNavBar: BottomNavBar} | {SideBar: SideBar} 
  header?: string | Widgets;
  
}
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
  onTap: actions.Action;
}
export interface SideBar {
  icon: string;
  iconLibrary?: string;
  label: string;
  page: string;
  selected: boolean;
  onTap: actions.Action;    
}



