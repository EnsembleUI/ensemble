import { Colors, iconLibrary } from "./common";
import { BaseStyles } from "./baseStyles";

enum alignment {
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
type backgroundColor = Colors;

type backgroundGradient = {
  backgroundGradient?: {
    /**
     *The list of colors used for the gradient
     */
    colors?: Colors[];
    /**
     * The starting position of the gradient
     */
    start?: alignment;
    /**
     * The ending position of the gradient
     */
    end?: alignment;
  };
};

type backgroundImage = {
  backgroundGradient: {
    /**
     * The Image URL to fill the background
     */
    source?: string;
    /**
     * How to fit the image within our width/height or our parent (if dimension is not specified)
     */
    fit?: fitEnum;
    alignment?: alignment;
  };
};

export type styleFlow = BaseStyles & {
  mainAxis?: any;
};

export interface HasBackground extends backgroundGradient {
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
