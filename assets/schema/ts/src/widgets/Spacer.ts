import { Widget } from "../widgetSchema";
import * as styles from "../styles";

export interface Spacer extends Widget {
  styles?: {
    size?: number;
  };
}
