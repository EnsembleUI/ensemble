import { TemplatedWidget, Widget } from "../widgetSchema";
import { BaseStyles, boxLayoutStyles } from "../styles";
import { Action } from "../actionSchema";

export interface GridView extends Widget, TemplatedWidget {
  /**
   * Call Ensemble's built-in functions or execute code when tapping on an item in the list.
   * */
  onItemTap?: Action;
  styles?: BaseStyles &
    boxLayoutStyles & {
      /**
       * The number of horizontal tiles (max 5) to show. If not specified, the number of tiles will automatically be
       * determined by the screen size. You may also specify a single number (for all breakpoints), three numbers
       * (for small, medium, large breakpoints), or five numbers (xSmall, small, medium, large, xLarge).
       * @minimum 1
       * @maximum 5
       * */
      horizontalTileCount?: number | string;
      /**
       * The gap between the horizontal tiles if there are more than one (default: 10).
       * @minimum 0
       * */
      horizontalGap?: number;
      /**
       * The gap between the vertical tiles if there are more than one (default: 10).
       * @minimum 0
       * */
      verticalGap?: number;
      /**
       * Set a fixed height for each item in the tile. If each tile item comprises of many widgets vertically, setting
       * this attribute may require you to stretch (expand) at least one inner widget.
       * @minimum 0
       * */
      itemHeight?: number;
      /**
       * Instead of itemHeight, you can set the tile's dimension as a ratio of (item width / item height). For example,
       * a tile with 3x width and 2x height is 3/2 = 1.5. This attribute will be ignored if itemHeight is set.
       * @minimum 0
       * */
      itemAspectRatio?: number;
    };
}
