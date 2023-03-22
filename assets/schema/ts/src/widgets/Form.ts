import { Widget } from "../widgetSchema";
import { Action } from "../actionSchema";
import { Widgets } from "../coreSchema";

enum labelEnum {
  top = "top",
  start = "start",
  none = "none",
}

enum labelOverflowEnum {
  wrap = "wrap",
  visible = "visible",
  clip = "clip",
  ellipsis = "ellipsis",
}

export interface Form extends Widget {
  enabled?: boolean;
  /**
   * Action to execute when the form is submitted
   * */
  onSubmit?: Action;
  children?: Widgets;
  styles?: {
    /**
     * Where the position the FormField's label
     * */
    labelPosition?: labelEnum;
    /**
     * Treatment of text longer than available space
     * */
    labelOverflow?: labelOverflowEnum;
    /**
     * @minimum 0
     * */
    width?: number;
    /**
     * @minimum 0
     * */
    height?: number;
    /**
     * Vertical gap to insert between the children (default is 10)
     * @minimum 0
     * */
    gap?: number;
  };
}
