import * as core from "./coreSchema";
import {
  alignmentEnum,
  backgroundColor,
  backgroundGradient,
  backgroundImage,
  BaseStyles,
  boxLayoutStyles,
  Colors,
  directionEnum,
  fittedBoxStyles,
  httpMethod,
  navIconPosition,
  screenType,
  styleCarousel,
  styleFlex,
  styleFlow,
  stylesColumn,
  stylesRow,
} from "./styles";
import { Action } from "./actionSchema";
import { RootWidgets, Widgets } from "./coreSchema";
export interface Widget {
  /**
   * ID to be referenced later
   * */
  id?: string;
}

/**
 * This is your root View. It requires a body widget.
 * */
export interface View extends RootWidgets {
  /**
   * Configure the application header
   * */
  header?: {
    /**
     * A simple text or a custom widget for the App's title
     * */
    title?: string | Widgets;
    /**
     * This widget (typically used as an background image) acts as the header's background, with the title bar and the
     * bottom widget overlaid on top. On non-scrollable screen, its dimensions is dictated by the header's width and
     * height.
     * */
    flexibleBackground?: Widgets;
    styles?: {
      /**
       * By default the background color uses the theme's 'primary' color. You can override the header's background
       * color here.
       * */
      backgroundColor?: Colors;
      /**
       * By default the navigation icon, title, and action icons uses the theme's 'onPrimary' color. You can override
       * their colors here.
       * */
      color?: Colors;
      /**
       * Raise the header on its z-coordinates relative to the body. This effectively creates a drop shadow on the
       * header's bottom edge.
       * @minimum 0
       * */
      elevation?: number;
      /**
       * If elevation is non-zero, this will override the drop shadow color of the header's bottom edge.
       * */
      shadowColor?: Colors;
      /**
       * Whether to align the title in the title bar's center horizontally (default: true)
       * */
      centerTitle?: boolean;
      /**
       * For consistency, the header's title bar has the default fixed height of 56 regardless of its content.
       * You may adjust its height here.
       * @minimum 0
       * */
      titleBarHeight?: number;
      /**
       * Applicable only if scrollableView is enabled. This attribute effectively sets the header's min height on
       * scrolling (header's height will varies between the flexibleMinHeight and flexibleMaxHeight). Note that this
       * attribute will be ignored if smaller than the titleBarHeight
       * */
      flexibleMinHeight?: number;
      /**
       * Applicable only if scrollableView is enabled. This attribute effectively sets the header's max height on
       * scrolling (header's height will varies between the flexibleMinHeight and flexibleMaxHeight). This attribute
       * will be ignored if smaller than the flexibleMinHeight
       * */
      flexibleMaxHeight?: number;
    };
  };
  body: Widgets;
  /**
   * Execute an Action when the screen loads
   * */
  onLoad?: Action;
  options?: {
    /**
     *Specify if this is a regular (default) or modal screen
     * */
    type?: screenType;
  };
  styles?: {
    backgroundColor?: backgroundColor;
    backgroundImage?: backgroundImage;
    /**
     * Applicable only when we don't have a header. If true, insert paddings around the body content to account for
     * the the devices' Safe Area (e.g. iPhone notch). Default is false.
     * */
    useSafeArea?: boolean;
    /**
     * Specify if the content of this screen is scrollable with a global scrollbar. Using this also allow you to
     * customize the scrolling experience of the header.
     * */
    scrollableView?: boolean;
    /**
     * For a screen with header, the App will automatically show the Menu, Back, or Close icon (for modal screen)
     * before the title. On modal screen without the header, the Close icon will be shown. Set this flag to false if
     * you wish to hide the icons and handle the navigation yourself.
     * */
    showNavigationIcon?: boolean;
    /**
     * On modal screen without a header, you can position the close button at the start or end of the screen.
     * For left-to-right languages like English, start is on the left and end is on the right. This property has
     * no effect on a screen with header.
     * */
    navigationIconPosition?: navIconPosition;
  };
}
/**
 * Javascript snippet for declaring variables and reusable functions, visible anywhere within this screen
 * */
export type Functions = string;

/**
 * Declare Javascript variables and functions that are visible globally within this screen.  \n//@code  \n
 * var myGlobalVar = 'hello';  \nfunction myGlobalFunc() {  \n  }
 * */
export type GlobalType = {
  value: `|- \\n \\t//@code\\n\\t`;
};

export type API = {
  /**
   * Define the list of input names that this API accepts
   * */
  inputs?: [];
  /**
   * The URL for this API
   * */
  uri: string;
  /**
   * Set the HTTP Method
   * */
  method: httpMethod;
  /**
   * Specify the key/value pairs to pass along with the URL
   * */
  parameters?: {};
  /**
   * The request body to pass along with the URL
   * */
  body?: string;
  /**
   * Execute this callback upon a successful return of the API (http code 200-299).
   * */
  onResponse?: Action;
  /**
   * Execute this callback when the API returns an error.
   * */
  onError?: Action;
};

export interface Container extends Widget {
  children?: (Widgets | string)[];
}

export interface Column extends Container, core.TemplatedWidget {
  styles?: stylesColumn;
}
export interface Row extends Container, core.TemplatedWidget {
  styles?: stylesRow;
}
export interface Flex extends Container, core.TemplatedWidget {
  styles?: styleFlex;
}
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

/**
 * Stretch to fit the parent (the parent is required to have a predetermined height), then distribute the vertical spaces
 * evenly among its children. You can override the space distribution via 'childrenFits' attribute.
 * */
export interface FittedBoxLayout extends Container {
  styles?: fittedBoxStyles;
}
