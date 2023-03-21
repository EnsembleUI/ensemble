import { Widget } from "../widgetSchema";
import * as styles from "../styles";

export interface Html extends Widget {
  /**
   * Enter the HTML text
   * */
  text?: string;
}
