export type Platform = 'ios' | 'android' | 'web';

export interface ArgumentParseResult {
  scripts: string[];
  argsArray: string[];
}

export interface Script {
  name: string;
  path: string;
  parameters: Parameter[];
}

export interface Parameter {
  key: string;
  question: string;
  type: string;
  choices?: string[];
  platform: Platform[];
}
