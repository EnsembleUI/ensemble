import { Widget } from "../widgetSchema";
import * as styles from "../styles";
import { Action } from "../actionSchema";
import { Colors } from "../styles";

enum progressEnum {
  linear = "linear",
  circular = "circular",
}

export interface Progress extends Widget {
  display?: progressEnum;
  /**
   * Show the progress percentage based on the number of seconds specified here
   * @minimum 0
   * */
  countdown?: number;
  /**
   * Execute this Action when the countdown comes to 0
   * */
  onCountdownComplete?: Action;
  styles?: styles.BaseStyles & {
    backgroundColor?: Colors;
    /**
     * Specifies the width (progress bar) or the diameter (circular progress indicator)
     * @minimum 10
     * */
    size?: number;
    /**
     * Specifies the thickness of the indicator (for progress bar this is the height)
     * @minimum 1
     * */
    thickness?: number;
    color?: Colors;
  };
}
