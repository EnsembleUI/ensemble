import { Widget } from "../widgetSchema";
import { FormInput } from "../styles";

export interface Time extends Widget, FormInput {
  /**
   *The highlighted initial time in the time picker. Use format HH:MM
   * */
  initialValue?: string;
}
