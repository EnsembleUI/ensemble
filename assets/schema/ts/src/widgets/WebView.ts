import { Widget } from "../widgetSchema";
import { BaseStyles } from "../styles";

export interface WebView extends Widget {
  url?: string;
  styles?: BaseStyles & {
    /**
     * By default the width will match its parent's available width, but you can set an explicit width here.
     * */
    width?: number;
    /**
     * If no height is specified, the web view will stretch its height to fit its content, in which case a scrollable
     * parent is required to scroll the content. You may override this behavior by explicitly set the web view's height
     * here, or uses 'expanded' to fill the available height.
     * */
    height?: number;
  };
}
