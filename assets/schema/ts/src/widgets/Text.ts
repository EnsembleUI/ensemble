import { Widget } from "../widgetSchema";
import * as styles from "../styles";

interface TextStyles
  extends styles.BoxStyles,
    styles.BaseStyles,
    Partial<styles.TextStyles> {}

export interface Text extends Widget {
  /**
   * @default "add your text"
   */
  text?: string;
  styles?: TextStyles;
}
