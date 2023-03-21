import { Widget } from "../widgetSchema";
import { FormInput } from "../styles";

export interface Date extends Widget, FormInput {
  /**
   * The highlighted initial date in the calendar picker (default is Today). Use format YYYY-MM-DD.
   * */
  initialValue?: string;
  /**
   * The first selectable date in the calendar. Use format YYYY-MM-DD
   * */
  firstDate?: string;
  /**
   * The last selectable date in the calendar. Use format YYYY-MM-DD
   * */
  lastDate?: string;
  /**
   * Whether we should show (default) or hide the calendar icon. Selecting the text will still open the calendar picker
   * */
  showCalendarIcon?: boolean;
}
