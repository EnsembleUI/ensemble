import * as core from './coreSchema';
import * as actions from './actionSchema';


/// base
export type Color = 'red' | 'green' | 'blue';

export type IconLibrary = 'default' | 'fontAwesome';
export interface HasIcon {
	name: number | string;
	library?: IconLibrary;
	color?: Color;
	size?: number
}

/// widgets
export type Widgets =
{ Text: Text } |
{ Markdown: Markdown} |
{ Html: Html} |
{ Icon: Icon} |
{ Lottie: Lottie} |
{ QrCode: QrCode} |
{ Progress: Progress} |
{ Divider: Divider} |
{ Spacer: Spacer} |

{ TextInput: TextInput} |
{ PasswordInput: PasswordInput} |
{ OnOff: OnOff} |
{ SelectOne: SelectOne} |
{ Date: Date} |
{ Time: Time} |
{ Button: Button} |

{ Form: Form} |
{ Flow: Flow} |
{ Column: Column} |
{ Row: Row} |
{ Flex: Flex} |
{ Stack: Stack} |
{ GridView: GridView} |
{ ListView: ListView} |
{ Carousel: Carousel};



export interface Widget {
	id?: string;
}
export interface Text extends Widget {
	text?: string;
}
export interface Markdown extends Widget {
	text?: string;
}
export interface Html extends Widget {
	text?: string;
}
// TO BE DONE
export interface Icon extends Widget {
	icon: string;
	library?: string;
	onTap: actions.Action;
}
export interface Lottie extends Widget {
	source: string;
}
export interface QrCode extends Widget {
	value: string;
}
export type ProgressDisplay = 'linear' | 'circular';
export interface Progress extends Widget {
	display?: ProgressDisplay;
	countdown?: number;
	onCountdownComplete?: actions.Action;
}
export interface Divider extends Widget {
}
export interface Spacer extends Widget {
	size?: number;
}

// input widgets
export interface Input extends Widget {
	label?: string;
	labelHint?: string;
	hintText?: string;
	required?: boolean;
	enabled?: boolean;
	icon?: HasIcon;
	onChange?: actions.Action;

}
export type InputType = 'default' | 'email' | 'phone' | 'ipAddress';
export interface TextInput extends Input {
	value?: string;
	inputType?: InputType;
	onKeyPress?: actions.Action;
	obscureText?: boolean;
	obscureToggle?: boolean;
}
export interface PasswordInput extends Input {
	value?: string;
	onKeyPress?: actions.Action;
}
export interface OnOff extends Input {
	value?: boolean;
	leadingText?: string;
	trailingText?: string;
}
export interface SelectOne extends Input {
	items?: [any];
	value?: string;
}
export interface Date extends Input {
	initialValue?: string;
	firstDate?: string;
	lastDate?: string;
	showCalendarIcon?: boolean;
}
export interface Time extends Input {
	initialValue?: string;
}
export interface Button extends Widget {
	label: string;
	enabled?: boolean;
	submitForm?: boolean;
	onTap?: actions.Action;
}




/// layouts
export interface HasChildren extends Widget {
	children?: [Widgets, ...Widgets[]];
}
export interface HasItemTemplate extends Widget {
  "item-template"?: ItemTemplate;
}
export interface ItemTemplate {
  data: string;
  name: string;
  template: Widget | string;
}
export interface Form extends HasChildren {
	enabled?: boolean;
	onSubmit?: actions.Action;
}
export type Direction = 'vertical' | 'horizontal';
export interface Flow extends HasChildren, HasItemTemplate {
	direction: Direction;
}
export interface Column extends HasChildren, HasItemTemplate {

}
export interface Row extends HasChildren, HasItemTemplate {
  
}
export interface Flex extends HasChildren, HasItemTemplate {
	styles?: FlexStyle;
}
export interface FlexStyle {
	direction?: Direction;
}
export interface Stack extends HasChildren {
}
export interface GridView extends HasItemTemplate {
  onItemTap?: actions.Action;
}
export interface ListView extends HasChildren, HasItemTemplate {
  onItemTap?: actions.Action;
  selectedItemIndex?: number;
}
export interface Carousel extends HasChildren, HasItemTemplate {
	onItemChange?: actions.Action;
}
