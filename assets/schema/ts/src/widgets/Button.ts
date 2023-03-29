import { Widget } from "../widgetSchema";
import { BaseStyles, BoxStyles, fontWeight, HasIcon } from "../styles";
import { Action } from "../actionSchema";

export interface Button extends Widget {
  /**
   * The button label
   * */
  label?: string;
  /**
   * Icon placed in front of the label, according to device text alignment
   * */
  startingIcon?: HasIcon;
  enabled?: boolean;
  /**
   * If the button is inside a Form and upon on tap, it will execute the form's onSubmit action if this property is TRUE
   * */
  submitForm?: boolean;
  /**
   * Call Ensemble's built-in functions or execute code
   * */
  onTap?: Action;
  styles?: BaseStyles &
    BoxStyles & {
      /**
       * Whether the button should have an outline border instead of filled background
       * */
      outline?: boolean;
      /**
       * Set the color for the button label starting with '0xFF' for full opacity
       * */
      color?: number | string;
      /**
       * @minimum 6
       * */
      fontSize?: number;
      fontWeight?: fontWeight;
    };
}
