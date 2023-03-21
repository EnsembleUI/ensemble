import { Widget } from "../widgetSchema";
import { FormInput } from "../styles";

export interface SelectOne extends Widget, FormInput {
  /**
   * Select a value that matches one of the items. If Items are Objects, it should match the value key
   * */
  value?: any;
  /**
   * List of values, or Objects with value/label pairs
   * */
  items?: any[];
}
