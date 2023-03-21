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

type ExclusiveUnion<A, B> = (A | B) extends object
  ? (Exclude<keyof A, keyof B> extends never ? B : A & B)
  : A | B;

export interface ViewGroup extends RootWidgets {
  menu?: ExclusiveUnion<{BottomNavBar: BottomNavBar}, {SideBar: SideBar}>;
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



