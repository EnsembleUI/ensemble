import { Widget } from "../widgetSchema";
import { FormInput, inputValidator, keyboardAction } from "../styles";
import { Action } from "../actionSchema";

export interface PasswordInput extends Widget, FormInput, inputValidator {
  /**
   * On every keystroke, call Ensemble's built-in functions or execute code
   * */
  onKeyPress?: Action;
  keyboardAction?: keyboardAction;
  /**
   * enable the toggling between plain and obscure text.
   * */
  obscureToggle?: boolean;
}
