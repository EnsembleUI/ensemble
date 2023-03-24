import { Widget } from "../widgetSchema";

export interface ChartJS extends Widget {
  styles?: {
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
   *Chartjs config. \nSee this for an example - https://www.chartjs.org/docs/latest/configuration/
   * */
  config?: string;
}
