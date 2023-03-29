import { Colors, directionEnum, iconLibrary } from "./common";
import { BaseStyles } from "./baseStyles";
import { Widget } from "../widgetSchema";

export enum alignmentEnum {
  topLeft = "topLeft",
  topCenter = "topCenter",
  topRight = "topRight",
  centerLeft = "centerLeft",
  center = "center",
  centerRight = "centerRight",
  bottomLeft = "bottomLeft",
  bottomCenter = "bottomCenter",
  bottomRight = "bottomRight",
}

enum indicatorEnum {
  none = "none",
  circle = "circle",
  rectangle = "rectangle",
}

enum indicatorPositionEnum {
  bottom = "bottom",
  top = "top",
}

enum layoutEnum {
  auto = "auto",
  single = "single",
  multiple = "multiple",
}

enum mainAxisEnum {
  start = "start",
  center = "center",
  end = "end",
  spaceBetween = "spaceBetween",
  spaceAround = "spaceAround",
  spaceEvenly = "spaceEvenly",
}

enum mainAxisSizeEnum {
  min = "min",
  max = "max",
}

enum crossAxisEnum {
  start = "start",
  center = "center",
  end = "end",
  stretch = "stretch",
  baseline = "baseline",
}

enum shadowEnum {
  /**
   * some description goes here
   * */
  "normal" = "normal",
  /**
   * some other new description
   * */
  "solid" = "solid",
}

export enum fitEnum {
  fill = "fill",
  contain = "contain",
  cover = "cover",
  fitWidth = "fitWidth",
  fitHeight = "fitHeight",
  none = "none",
  scaleDown = "scaleDown",
}

enum itemDisplayEnum {
  stacked = "stacked",
  sideBySide = "sideBySide",
}

type borderProperties = {
  /**
   * Border color, starting with '0xFF' for full opacity
   */
  borderColor?: Colors;
  /**
   * The thickness of the border
   * @minimum 0
   */
  borderWidth?: number;
};

export type borderRadius = {
  /**
   * Border Radius with CSS-like notation (1 to 4 integers)
   * @minimum 0
   */
  borderRadius?: number | string;
};

type styleBorder = borderProperties & borderRadius;

export type styleMargin = {
  /**
   * Margin with CSS-style notation e.g. margin: 5 20 5
   */
  margin?: number | string;
};

export type styleShadow = {
  /**
   * Box shadow color starting with '0xFF' for full opacity
   */
  shadowColor?: number | string;
  shadowOffset?: number[];
  /**
   * @minimum 0
   */
  shadowRadius?: number;
  /**
   * The blur style to apply on the shadow
   * */
  shadowStyle?: shadowEnum;
};

export type stylePadding = {
  /**
   * Padding with CSS-style value e.g. padding: 5 20 5
   */
  padding?: number | string;
};
/**
 *
 * Background color, starting with '0xFF' for full opacity e.g 0xFFCCCCCC
 */
export type backgroundColor = Colors;

export type backgroundGradient = {
  /**
   *The list of colors used for the gradient
   */
  colors?: Colors[];
  /**
   * The starting position of the gradient
   */
  start?: alignmentEnum;
  /**
   * The ending position of the gradient
   */
  end?: alignmentEnum;
};

export type backgroundImage = {
  /**
   * The Image URL to fill the background
   */
  source?: string;
  /**
   * How to fit the image within our width/height or our parent (if dimension is not specified)
   */
  fit?: fitEnum;
  alignment?: alignmentEnum;
};
type itemType = {
  /**
   * Icon name from Material Icons or Font Awesome
   * */
  icon: string;
  iconLibrary?: iconLibrary;
  label: string;
  /**
   * The new page to navigate to on click
   * */
  page: string;
  /**
   * Mark this item as selected. There should only be one selected item per page.
   * */
  selected?: boolean;
};
export type MenuBase = {
  /**
   * List of menu items (minimum 2)
   * */
  items: itemType[];
  styles?: backgroundColor;
};

export type MenuWithHeaderAndFooter = MenuBase & {
  /**
   * The header widget for the menu
   * */
  header?: Widget;
  /*
   * The footer widget for the menu
   * */
  footer?: Widget;
};

export type MenuWithAdditionalStyles = MenuWithHeaderAndFooter & {
  styles?: borderProperties & {
    /**
     * How to render each navigation item
     * */
    itemDisplay?: itemDisplayEnum;
    /**
     * Padding for each navigation item with CSS-style value
     * */
    itemPadding?: string | number;
    /**
     * The minimum width for the menu (default 200)
     * */
    minWidth?: number;
  };
};
export type boxLayoutStyles = BoxStyles & {
  /**
   * @minimum 0
   * */
  gap?: number;
  /**
   * Set the font family applicable for all widgets inside this container
   * */
  fontFamily?: string;
  /**
   * @minimum 0
   * */
  fontSize?: number;
};

export type stylesColumn = BaseStyles &
  boxLayoutStyles & {
    /**
     * Control our children's layout vertically
     * */
    mainAxis?: mainAxisEnum;
    /**
     * Control the horizontal alignment of the children
     * */
    crossAxis?: crossAxisEnum;
    /**
     * Stretch to the max vertically or only fit the vertical space
     * */
    mainAxisSize?: mainAxisSizeEnum;
    /**
     * Set to true so content can scroll vertically as needed
     * */
    scrollable?: boolean;
    /**
     * Explicitly make the column's width as wide as the largest child, but only if our column's parent does not already
     * assign a width. This attribute is useful for sizing children who don't have a width (e.g Divider)
     * */
    autoFit?: boolean;
  };

export type stylesRow = BaseStyles &
  boxLayoutStyles & {
    /**
     * Control our children's layout horizontally
     * */
    mainAxis?: mainAxisEnum;
    /**
     * Control the vertical alignment of the children
     * */
    crossAxis?: crossAxisEnum;
    /**
     * Stretch to the max horizontally or only fit the horizontal space
     * */
    mainAxisSize?: mainAxisSizeEnum;
    /**
     * Set to true so content can scroll horizontally as needed
     * */
    scrollable?: boolean;
    /**
     * Explicitly make the row's height as tall as the largest child, but only if the row's parent does not already
     * assign us a height. This attribute is useful for sizing children who don't have a width (e.g vertical Divider)
     * */
    autoFit?: boolean;
  };

export type styleFlow = BaseStyles & {
  /**
   * Control our children's layout vertically
   * */
  mainAxis?: mainAxisEnum;
  /**
   *The gap between the children in the main direction
   * @minimum 0
   * */
  gap?: number;
  /**
   * The gap between the lines if the children start wrapping
   * @minimum 0
   * */
  lineGap?: number;
  /**
   * @minimum 0
   * */
  maxWidth?: number;
  /**
   * @minimum 0
   * */
  maxHeight?: number;
};

export type styleFlex = BaseStyles &
  boxLayoutStyles & {
    /**
     * Lay out the children vertically or horizontally
     * */
    direction?: directionEnum;
    /**
     * Control how to lay out the children, in the direction specified by the 'direction' attribute
     * */
    mainAxis?: mainAxisEnum;
    /**
     * Control the alignment of the children on the secondary axis (depending on the 'direction' attribute)
     * */
    crossAxis?: crossAxisEnum;
    /**
     * stretch to the max or only fit the available space of the main axis (depending on the 'direction' attribute)
     * */
    mainAxisSize?: mainAxisSizeEnum;
    /**
     * Set to true so content can scroll vertically or horizontally as needed
     * */
    scrollable?: boolean;
    /**
     * Explicitly match the width or height to the largest child's size, but only if the parent does not already assign
     * a width or height. This attribute is useful for sizing children who don't have a width or height (e.g Divider)
     * */
    autoFit?: boolean;
  };

export type styleCarousel = WithoutDimension & {
  /**
   * Show a SingleView (on screen one at a time), MultiView (scrolling items), or automatically switch between the views
   * with autoLayoutBreakpoint
   * */
  layout?: layoutEnum;
  /**
   *  Show multiple views on the carousel if the breakpoint is equal or larger than this threshold, otherwise show
   *  single view. (default 768)
   * */
  autoLayoutBreakpoint?: number;
  /**
   * The height of each view
   * */
  height?: number;
  /**
   * The gap between each views, but also act as a left-right margin in a single view
   * */
  gap?: number;
  /**
   * The space before the first item. Note that the left edge of the scroll area is still controlled by padding or
   * margin.
   * */
  leadingGap?: number;
  /**
   * The space after the last item. Note that the right edge of the scroll area is still controlled by padding or
   * margin.
   * */
  trailingGap?: number;
  /**
   * The screen width ratio for each carousel item (in single item mode). Value ranges from 0.0 to 1.0 for the full
   * width. (default 1.0)
   * @minimum 0
   * @maximum 1
   * */
  singleItemWidthRatio?: number;
  /**
   * The screen width ratio for each carousel item (in multiple item mode). Value ranges from 0.0 to 1.0 for the
   * full width (default 0.6)
   * @minimum 0
   * @maximum 1
   * */
  multipleItemWidthRatio?: number;
  /**
   * How the view indicator should be displayed
   * */
  indicatorType?: indicatorEnum;
  /**
   * Where to display the indicator if specified
   * */
  indicatorPosition?: indicatorPositionEnum;
  indicatorWidth?: number;
  indicatorHeight?: number;
  /**
   * The margin around each indicator
   * */
  indicatorMargin?: number | string;
};

/**
 *Allow this selected child to determine its own size. This may give an error if the child doesn't have a dimension.
 * */
type auto = "auto";

/**
 * Default 1. After laying out the 'auto' children, the left-over space will be divided up based on this multiple.
 * @minimum 1
 * */
type min = number;

export type fittedBoxStyles = BaseStyles &
  boxLayoutStyles &
  Pick<stylesColumn, "mainAxis" | "crossAxis"> & {
    /**
     *  Specify an array of non-zero integers or 'auto', each corresponding to a child. Setting 'auto' will let the child
     *  determines its own size, while setting a non-zero integer will determine the child's size multiple. The 'auto'
     *  children will be laid out first and get as much space as they need, then the left-over space will be distributed
     *  to the other children based on their size multiples.
     * */
    childrenFits?: (auto | min)[];
  };

export interface HasBackground extends Partial<backgroundGradient> {
  backgroundColor?: Colors;
  backgroundImage?: backgroundImage;
}

export type HasDimension = {
  /**
   * @minimum 0
   * */
  width?: number;
  /**
   * @minimum 0
   * */
  height?: number;
};

/**
 * Specifies the icon to use. You can also use the short-handed syntax 'iconName iconLibrary')
 * */
export type HasIcon = {
  /**
   * The name of the icon
   * */
  name?: string | number;
  /**
   * Which icon library to use.
   * */
  library?: iconLibrary;
  color?: Colors;
  /**
   * @minimum 0
   * */
  size?: number;
};

export interface WithoutDimension
  extends styleMargin,
    stylePadding,
    HasBackground,
    styleBorder,
    styleShadow {}

export interface BoxStyles extends HasDimension, WithoutDimension {}
