import { Widget } from "../widgetSchema";

export interface Video extends Widget {
  /**
   * The URL source to the media file
   * */
  source?: string;
}
