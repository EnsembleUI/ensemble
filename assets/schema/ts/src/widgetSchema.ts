import * as core from "./coreSchema";
import {
  alignmentEnum,
  BaseStyles,
  boxLayoutStyles,
  Colors,
  directionEnum,
  styleCarousel,
  styleFlex,
  styleFlow,
  stylesColumn,
  stylesRow,
} from "./styles";
import { Action } from "./actionSchema";
export interface Widget {
  /**
   * ID to be referenced later
   * */
  id?: string;
}

export interface Container extends Widget {
  children?: [core.Widgets, ...core.Widgets[]];
}

export interface Column extends Container, core.TemplatedWidget, stylesColumn {}
export interface Row extends Container, core.TemplatedWidget, stylesRow {}
export interface Flex extends Container, core.TemplatedWidget, styleFlex {}
export interface Stack extends Container {
  styles?: {
    alignment?: alignmentEnum;
  };
}
export interface ListView extends Container, core.TemplatedWidget {
  /**
   * Dispatch when an ListView item is selected/tapped.The event dispatches only when you tap on the item.
   * The index of the item can be retrieved using 'selectedItemIndex'.
   * */
  onItemTap?: Action;
  /**
   * Selecting a ListView item gives the index of selected item
   * */
  selectedItemIndex?: number;
  styles?: BaseStyles &
    boxLayoutStyles & {
      /**
       * Set the color for the separator between items
       * */
      separatorColor?: Colors;
      /**
       *The thickness of the separator between items
       * */
      separatorWidth?: number;
      /**
       * Padding with CSS-style value e.g. padding: 5 20 5 Default 0 0 0
       * */
      separatorPadding?: number | string;
    };
}

export interface Flow extends Container, core.TemplatedWidget {
  /**
   *The main direction to lay out the children before wrapping
   * */
  direction?: directionEnum;
  styles?: styleFlow;
}

export interface Carousel extends Container, core.TemplatedWidget {
  /**
   * Dispatch when an carousel item is in focus. For SingleView, this happens when the item is scroll into view. For
   * scrolling MultiView, the event dispatches only when you tap on the item. The index of the item can be retrieved
   * using 'selectedIndex'.
   * */
  onItemChange?: Action;
  styles?: styleCarousel;
}
