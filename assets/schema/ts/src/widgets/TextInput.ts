import { Widget } from "../widgetSchema";
import { FormInput, inputValidator, keyboardAction } from "../styles";
import { Action } from "../actionSchema";

enum inputType {
  default = "default",
  email = "email",
  phone = "phone",
  ipAddress = "ipAddress",
}

export interface TextInput extends Widget, FormInput, inputValidator {
  /**
   * On every keystroke, call Ensemble's built-in functions or execute code
   * */
  onKeyPress?: Action;
  /**
   * Specifying the value of your Text Input
   * */
  value?: string;
  /**
   * Pick a predefined input type
   * */
  inputType?: inputType;
  keyboardAction?: keyboardAction;
  /*
   * whether we should obscure the typed-in text (e.g Social Security)
   * */
  obscureText?: boolean;
  /**
   * enable the toggling between plain and obscure text.
   * */
  obscureToggle?: boolean;
  styles?: {
    /**
     * @minimum 6
     * */
    fontSize?: number;
  };
}
