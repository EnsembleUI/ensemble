import { Widget } from "../widgetSchema";
import * as styles from "../styles";

export interface Lottie extends Widget {
  /**
   * URL or asset name of the Lottie json file
   */
  source: string;
  styles?: styles.BaseStyles &
    styles.BoxStyles &
    styles.HasDimension & {
      /**
       * Whether we should repeat the animation (default true)
       * */
      repeat?: boolean;
      /**
       * How to fit the Lottie animation within our width/height or our parent (if dimension is not specified)
       * */
      fit?: styles.fitEnum;
    };
}
