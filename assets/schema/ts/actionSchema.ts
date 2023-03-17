export type Action = {invokeAPIAction: InvokeAPIAction}
        | {executeCodeAction: ExecuteCodeAction};
export interface InvokeAPIAction {
  name: string;
  inputs?: {};
}
export interface ExecuteCodeAction {
  body: string;
  onComplete?: Action;
}