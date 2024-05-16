import * as core from './coreSchema';
export interface Widget {
    id?: string;
}

export interface Text extends Widget {
    text: string;
}

export interface Container extends Widget {
    children?: [core.Widgets, ...core.Widgets[]];
}
export interface Column extends Container,core.TemplatedWidget {

}
export interface Row extends Container,core.TemplatedWidget{
  
}