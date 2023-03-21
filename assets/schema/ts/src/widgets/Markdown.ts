import { Widget } from "../widgetSchema";
import * as styles from "../styles";

interface MarkdownStyles extends styles.BaseStyles {
  /**
   * Styling for regular text. Default to theme's bodyMedium styling
   */
  textStyle?: styles.styleText;
  /**
   * Styling for URL
   */
  linkStyle?: styles.styleText;
}

export interface Markdown extends Widget {
  /**
   * Your text in markdown format
   * */
  text?: string;

  styles?: MarkdownStyles;
}
