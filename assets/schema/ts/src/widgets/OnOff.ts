import { Widget } from "../widgetSchema";
import { FormInput } from "../styles";

export interface OnOff extends Widget, FormInput {
  value?: boolean;
  leadingText?: string;
  trailingText?: string;
}
