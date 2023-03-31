import { Widgets } from "./coreSchema";
import {
  borderRadius,
  Colors,
  DialogOptions,
  ShowToastOptions,
  stylePadding,
  styleShadow,
  TimerOptions,
} from "./styles";

export type Action = {
  invokeAPI?: InvokeAPIAction;
  executeCode?: ExecuteCodeAction;
  navigateScreen?: NavigateScreenAction;
  navigateModalScreen?: NavigateModalScreenAction;
  navigateBack?: NavigateBackAction;
  openCamera?: OpenCameraAction;
  showDialog?: ShowDialogAction;
  closeAllDialogs?: CloseAllDialogsAction;
  startTimer?: StartTimerAction;
  stopTimer?: StopTimerAction;
  showToast?: ShowToastAction;
  getLocationAction?: GetLocationAction;
};

/*
 * Navigating to a new screen
 * */
export interface NavigateScreenAction {
  /*
   * Enter the Name or ID of your Screen
   * */
  name: string;
  /*
   * Specify the key/value pairs to pass into the next Screen
   * */
  inputs?: {};
  options?: {
    /*
     *  If true, the new screen will replace the current screen on the navigation history.
     *  Navigating back from the new screen will skip the current screen.
     *  */
    replaceCurrentScreen?: boolean;
    /*
     * If true, clear out all existing screens in the navigation history. This is useful when navigating to a Logout
     * or similar page where users should not be able to go back to the prior screens.
     * */
    clearAllScreens?: boolean;
  };
}

/*
 * Navigating to a new screen as a modal
 * */
export interface NavigateModalScreenAction {
  /*
   * Enter the Name or ID of your Screen
   * */
  name: string;
  /*
   * Specify the key/value pairs to pass into the next Screen
   * */
  inputs?: {};
  /*
   * Execute an Action when the modal screen is dismissed
   * */
  onModalDismiss?: Action;
}

/*
 * Navigating back to the previous screen if possible. The current screen will be removed from the navigation history.
 * This also works for a modal screen.
 * */
export interface NavigateBackAction {}

/*
 * Calling an API
 * */
export interface InvokeAPIAction {
  /*
   * Give the API an ID allows you to bind to its result. e.g. ${apiId.body...}
   * */
  id?: string;
  /*
   * Enter the name of your defined API
   * */
  name: string;
  /*
   * Specify the key/value pairs to pass to the API
   * */
  inputs?: {};
  /*
   * Execute another Action upon API's successful response
   * */
  onResponse?: Action;
  /*
   * Execute an Action when the API completes with error(s)
   * */
  onError?: Action;
}

export interface OpenCameraAction {}

/*
 * Opening a dialog
 * */
export interface ShowDialogAction {
  /*
   * Return an inline widget or specify a custom widget's name to use in the dialog.
   * */
  widget: Widgets;
  options?: DialogOptions;
  /*
   * Execute an Action when the dialog is dismissed.
   * */
  onDialogDismiss?: Action;
}

/*
 * Closing all opened dialogs
 * */
export interface CloseAllDialogsAction {}

/*
 * Initiating the start of a timer
 * */
export interface StartTimerAction {
  /*
   * Give this timer an ID so it can be cancelled by a stopTimer action
   * */
  id?: string;
  /*
   * Execute an Action every time the timer triggers
   * */
  onTimer: Action;
  /*
   * Execute an Action when the timer has completed and will terminate
   * */
  onTimerComplete?: Action;
  options?: TimerOptions;
}

/*
 * Stop a timer if its running
 * */
export interface StopTimerAction {
  /*
   * Stop the timer with this ID if it is running
   * */
  id: string;
}

/*
 * Showing a toast message
 * */
export interface ShowToastAction {
  value: Widgets | { message: string };
  /*
   * The toast message. Either this message or a widget must be provided.
   * */
  message?: string;
  /*
   * The custom widget to show as the Toast's body. Either this widget or a toast message must be provided.
   * */
  widget?: Widgets;
  options?: ShowToastOptions;
  styles?: {
    /*
     * Toast's background color
     * */
    backgroundColor?: Colors;
  } & stylePadding &
    borderRadius &
    Pick<styleShadow, "shadowColor" | "shadowRadius" | "shadowOffset">;
}

/*
 * Execute a block of code.
 * */
export interface ExecuteCodeAction {
  body: string;
  /*
   * Execute another Action when the code body finishes executing
   * */
  onComplete?: Action;
}

/*
 * Requesting user's permission to get his/her current location
 * */
export interface GetLocationAction {
  options?: {
    /*
     * Whether to continuously get the device location on this screen. Note that a screen can only have one recurring
     *  location listener. Adding multiple recurring location listeners will cancel the previous one.
     * */
    recurring?: boolean;
    /**
     * If recurring, the minimum distance (in meters) the device has moved before new location is returned.
     * (default: 1000 meters, minimum: 50 meters)
     * @minimum 50
     * */
    recurringDistanceFilter?: number;
  };
  /*
   * Callback Action once we get the device location
   * */
  onLocationReceived?: Action;
  /*
   * Callback Action if we are unable to get the device location. Reason is available under 'reason' field
   * */
  onError?: Action;
}
