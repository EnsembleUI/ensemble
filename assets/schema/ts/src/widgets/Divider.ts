import { Widget } from "../widgetSchema";
import * as styles from "../styles";
import { directionEnum } from "../styles";

export interface Divider extends Widget {
  styles?: styles.BaseStyles &
    styles.styleMargin & {
      /**
       * Whether to display a horizontal divider (default) or vertical divider.
       * */
      direction?: directionEnum;
      thickness?: number;
      /**
       * The line color starting with '0xFF' for full opacity
       * */
      color?: number | string;
      /**
       * The leading gap before the line starts
       * */
      indent?: number;
      /**
       * The ending gap after the line ends
       * */
      endIndent?: number;
    };
}
