import { Widgets } from "../coreSchema";
import { Widget } from "../widgetSchema";
import { BaseStyles } from "../styles";

export interface Map extends Widget {
  currentLocation: {
    /**
     * If enabled, this will prompt the user for location access. User location will then be shown on the map
     * */
    enabled?: boolean;
    /**
     * The widget to render the user's location
     * */
    widget?: Widgets;
  };
  markers?: {
    data: string;
    name: string;
    location: {
      /**
       * The latitude of the marker
       * */
      lat: number;
      /**
       * The longitude of the marker
       * */
      lng: number;
    };
    widget: Widgets;
    /**
     * The widget to render a selected marker
     * */
    selectedWidget?: Widgets;
    /**
     * The widget to render as an overlay at the bottom of the map. Use this to convey more detail info.
     * */
    selectedWidgetOverlay?: Widgets;
  };
  styles?: BaseStyles & {
    /**
     * The width of each marker. (default 60)
     * */
    markerWidth?: number;
    /**
     * The height of each marker. (default 30)
     * */
    markerHeight?: number;
  };
}
