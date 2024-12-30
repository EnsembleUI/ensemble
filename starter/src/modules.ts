import {
  firebaseAndroidParameters,
  firebaseIOSParameters,
  firebaseWebParameters,
} from './common-params';
import { Script } from './interfaces';
import { requiredForPlatform } from './utils';

// Common parameters available across scripts and modules
export const commonParameters = [
  {
    key: 'platform',
    question: 'Which platform(s) are you targeting?',
    type: 'checkbox',
    choices: ['ios', 'android', 'web'],
    required: true,
  },
  {
    key: 'ensemble_version',
    question: 'Which version of ensemble are you using?',
    required: false,
    type: 'text',
  },
];

// Modules (called with `enable` command)
export const modules: Script[] = [
  {
    name: 'camera',
    path: 'scripts/modules/enable_camera.dart',
    parameters: [
      {
        key: 'cameraDescription',
        question: 'Please provide a camera usage description for iOS: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'file_manager',
    path: 'scripts/modules/enable_files.dart',
    parameters: [
      {
        key: 'photoLibraryDescription',
        question:
          'Please provide a description for accessing the photo library: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
      {
        key: 'musicDescription',
        question: 'Please provide a description for accessing music files: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'contacts',
    path: 'scripts/modules/enable_contacts.dart',
    parameters: [
      {
        key: 'contactsDescription',
        question: 'Please provide a description for accessing contacts: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'plaid_connect',
    path: 'scripts/modules/enable_connect.dart',
    parameters: [
      {
        key: 'cameraDescription',
        question: 'Please provide a camera usage description: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'location',
    path: 'scripts/modules/enable_location.dart',
    parameters: [
      {
        key: 'inUseLocationDescription',
        question:
          'Please provide a description for using location services while the app is in use: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
      {
        key: 'alwaysUseLocationDescription',
        question:
          'Please provide a description for using location services always: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
      {
        key: 'locationDescription',
        question:
          'Please provide a description for using location services always and when the app is in use: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'deeplink',
    path: 'scripts/modules/enable_deeplink.dart',
    parameters: [
      {
        key: 'branchIOLiveKey',
        question: 'Please provide the live Branch.io key: ',
        required: true,
        type: 'text',
      },
      {
        key: 'branchIOTestKey',
        question: 'Please provide the test Branch.io key: ',
        required: true,
        type: 'text',
      },
      {
        key: 'branchIOUseTestKey',
        question: 'Are you using the test key? (yes/no): ',
        type: 'list',
        choices: ['yes', 'no'],
        required: true,
      },
      {
        key: 'branchIOScheme',
        question: 'Please provide the URI scheme for deeplinking: ',
        required: true,
        type: 'text',
      },
      {
        key: 'branchIOLinks',
        question: 'Please provide a comma-separated list of deeplink URLs: ',
        required: true,
        type: 'text',
      },
    ],
  },
  {
    name: 'firebase_analytics',
    path: 'scripts/modules/enable_firebase_analytics.dart',
    parameters: [
      ...firebaseAndroidParameters,
      ...firebaseIOSParameters,
      ...firebaseWebParameters,
      {
        key: 'enableConsoleLogs',
        question: 'Do you want to enable Firebase console logs? (yes/no): ',
        type: 'list',
        choices: ['yes', 'no'],
        required: true,
      },
    ],
  },
  {
    name: 'notification',
    path: 'scripts/modules/enable_notifications.dart',
    parameters: [
      ...firebaseAndroidParameters,
      ...firebaseIOSParameters,
      ...firebaseWebParameters,
    ],
  },
  {
    name: 'bracket',
    path: 'scripts/modules/enable_bracket.dart',
    parameters: [],
  },
  {
    name: 'network_info',
    path: 'scripts/modules/enable_network_info.dart',
    parameters: [
      {
        key: 'inUseLocationDescription',
        question:
          'Please provide a description for using location services while accessing network info: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
      {
        key: 'alwaysUseLocationDescription',
        question:
          'Please provide a description for always using location services for network info: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
      {
        key: 'preciseLocationDescription',
        question:
          'Please provide a description for using precise location services for network info: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'ai_chat',
    path: 'scripts/modules/enable_chat.dart',
    parameters: [],
  },
  {
    name: 'auth',
    path: 'scripts/modules/enable_auth.dart',
    parameters: [
      ...firebaseAndroidParameters,
      ...firebaseIOSParameters,
      ...firebaseWebParameters,
      {
        key: 'googleIOSClientId',
        question: 'Please provide your iOS client ID: ',
        required: false,
        type: 'text',
      },
      {
        key: 'googleAndroidClientId',
        question: 'Please provide your Android client ID: ',
        required: false,
        type: 'text',
      },
      {
        key: 'googleWebClientId',
        question: 'Please provide your Web client ID: ',
        required: false,
        type: 'text',
      },
      {
        key: 'googleServerClientId',
        question: 'Please provide your server client ID: ',
        required: false,
        type: 'text',
      },
    ],
  },
  {
    name: 'bluetooth',
    path: 'scripts/modules/enable_bluetooth.dart',
    parameters: [
      {
        key: 'bluetoothDescription',
        question: 'Please provide a description for accessing Bluetooth: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
      {
        key: 'bluetoothPeripheralDescription',
        question:
          'Please provide a description for using Bluetooth peripherals: ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'biometric',
    path: 'scripts/modules/enable_biometric.dart',
    parameters: [
      {
        key: 'faceIdDescription',
        question: 'Please provide a description for Face ID usage (iOS): ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
    ],
  },
  {
    name: 'qr_code',
    path: 'scripts/modules/enable_qr_code.dart',
    parameters: [],
  },
  {
    name: 'google_maps',
    path: 'scripts/modules/enable_google_maps.dart',
    parameters: [
      {
        key: 'iOSGoogleMapsApiKey',
        question: 'Please provide your Google Maps API key for iOS ',
        required: requiredForPlatform('ios'),
        type: 'text',
      },
      {
        key: 'androidGoogleMapsApiKey',
        question: 'Please provide your Google Maps API key for Android ',
        required: requiredForPlatform('android'),
        type: 'text',
      },
      {
        key: 'webGoogleMapsApiKey',
        question: 'Please provide your Google Maps API key for Web ',
        required: requiredForPlatform('web'),
        type: 'text',
      },
    ],
  },
];

// Custom Scripts (standalone Dart scripts)
export const scripts: Script[] = [
  {
    name: 'generateKeystore',
    path: 'scripts/generate_keystore.dart',
    parameters: [
      {
        key: 'storePassword',
        question: 'Please provide the store password: ',
        required: true,
        type: 'text',
      },
      {
        key: 'keyPassword',
        question: 'Please provide the key password: ',
        required: true,
        type: 'text',
      },
      {
        key: 'keyAlias',
        question: 'Please provide the key alias: ',
        required: true,
        type: 'text',
      },
    ],
  },
];
