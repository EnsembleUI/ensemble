import { Widget } from "../widgetSchema";
import * as styles from "../styles";
import { Action } from "../actionSchema";
import { Colors } from "../styles";

export interface Image extends Widget {
  /**
   * URL to or asset name of the image. If the URL is used, it is highly recommended that the dimensions is set (either
   * with width/height or other means) to prevent the UI jerkiness while loading
   */
  source: string;
  /**
   * Call Ensemble's built-in functions or execute code
   * */
  onTap?: Action;
  styles?: styles.BaseStyles &
    styles.BoxStyles & {
      /**
       * The placeholder color while the image is loading.
       */
      placeholderColor?: Colors;
      /**
       * How to fit the image within our width/height or our parent (if dimension is not specified)
       **/
      fit?: styles.fitEnum;
      /**
       * Images will be automatically resized (default to 800 width with no height set) before rendering.
       * If you know the rough image width, set this number to be the same or a slightly larger width to optimize the
       * loading time. To maintain the original aspect ratio, set either resizedWidth or resizedHeight, but not both.
       * This setting is not supported on Web.
       * @minimum 0
       * @maximum 2000
       * */
      resizedWidth?: number;
      /**
       * Images will be automatically resized (default to 800 width with no height set) before rendering.
       * If you know the rough image height, set this number to be the same or a slightly larger height to optimize the
       * loading time. To maintain the original aspect ratio, set either resizedWidth or resizedHeight, but not both.
       * This setting is not supported on Web.
       * @minimum 0
       * @maximum 2000
       * */
      resizedHeight?: number;
    };
}
