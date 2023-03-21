import { Widget } from "../widgetSchema";
import * as styles from "../styles";
import { Action } from "../actionSchema";
import { Colors, iconLibrary } from "../styles";

export interface Icon extends Widget {
  /**
   * Icon name from Material Icons or Font Awesome
   * */
  icon: string;
  library?: iconLibrary;
  /**
   * Call Ensemble's built-in functions or execute code
   */
  onTap?: Action;
  styles?: styles.BaseStyles &
    styles.WithoutDimension & {
      size?: number;
      /**
       * The color of the icon
       * */
      color?: Colors;
      /**
       * If onTap is defined, this color will show up as a splash effect upon tapping the icon. Note that the effect only
       *  happens if backgroundColor is not set.
       * */
      splashColor?: Colors;
    };
}
