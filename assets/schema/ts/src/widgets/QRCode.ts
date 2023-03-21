import { Widget } from "../widgetSchema";
import * as styles from "../styles";

export interface QRCode extends Widget {
  /**
   * The data to generate the QR code
   * */
  value: string;
  styles?: styles.BaseStyles &
    styles.WithoutDimension & {
      /**
       *Specify the width/height of the QR Code. Default: 160
       * */
      size?: number;
      /**
       *Set the color for the QR code drawing
       * */
      color?: styles.Colors;
    };
}
