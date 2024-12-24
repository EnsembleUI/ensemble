interface ModuleParameter {
  key: string;
  question: string;
  type?: string;
  choices?: string[];
  required?: boolean | ((args: any) => boolean);
}

interface Module {
  name: string;
  path: string;
  parameters: ModuleParameter[];
}

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
  },
];

// Modules (called with `enable` command)
export const modules: Module[] = [
  {
    name: 'camera',
    path: 'scripts/modules/enable_camera.dart',
    parameters: [
      {
        key: 'cameraDescription',
        question: 'Please provide a camera usage description for iOS: ',
        required: (args) => args.platform.includes('ios'),
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
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'musicDescription',
        question: 'Please provide a description for accessing music files: ',
        required: (args) => args.platform.includes('ios'),
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
        required: (args) => args.platform.includes('ios'),
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
        required: (args) => args.platform.includes('ios'),
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
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'alwaysUseLocationDescription',
        question:
          'Please provide a description for using location services always: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'locationDescription',
        question:
          'Please provide a description for using location services always and when the app is in use: ',
        required: (args) => args.platform.includes('ios'),
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
      },
      {
        key: 'branchIOTestKey',
        question: 'Please provide the test Branch.io key: ',
        required: true,
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
      },
      {
        key: 'branchIOLinks',
        question: 'Please provide a comma-separated list of deeplink URLs: ',
        required: true,
      },
    ],
  },
  {
    name: 'firebase_analytics',
    path: 'scripts/modules/enable_firebase_analytics.dart',
    parameters: [
      {
        key: 'android_apiKey',
        question: 'Please provide your Firebase Android API key: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_appId',
        question: 'Please provide your Firebase Android App ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_messagingSenderId',
        question: 'Please provide your Firebase Android Messaging Sender ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_projectId',
        question: 'Please provide your Firebase Android Project ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_storageBucket',
        question: 'Please provide your Firebase Android Storage Bucket: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_authDomain',
        question: 'Please provide your Firebase Android Auth Domain: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'ios_apiKey',
        question: 'Please provide your Firebase iOS API key: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_appId',
        question: 'Please provide your Firebase iOS App ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_messagingSenderId',
        question: 'Please provide your Firebase iOS Messaging Sender ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_projectId',
        question: 'Please provide your Firebase iOS Project ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_storageBucket',
        question: 'Please provide your Firebase iOS Storage Bucket: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_authDomain',
        question: 'Please provide your Firebase iOS Auth Domain: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'web_apiKey',
        question: 'Please provide your Firebase Web API key: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_appId',
        question: 'Please provide your Firebase Web App ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_authDomain',
        question: 'Please provide your Firebase Web Auth Domain: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_messagingSenderId',
        question: 'Please provide your Firebase Web Messaging Sender ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_projectId',
        question: 'Please provide your Firebase Web Project ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_storageBucket',
        question: 'Please provide your Firebase Web Storage Bucket: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_measurementId',
        question: 'Please provide your Firebase Web Measurement ID: ',
        required: (args) => args.platform.includes('web'),
      },
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
      {
        key: 'android_apiKey',
        question: 'Please provide your Firebase Android API key: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_appId',
        question: 'Please provide your Firebase Android App ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_messagingSenderId',
        question: 'Please provide your Firebase Android Messaging Sender ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_projectId',
        question: 'Please provide your Firebase Android Project ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_storageBucket',
        question: 'Please provide your Firebase Android Storage Bucket: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_authDomain',
        question: 'Please provide your Firebase Android Auth Domain: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'ios_apiKey',
        question: 'Please provide your Firebase iOS API key: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_appId',
        question: 'Please provide your Firebase iOS App ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_messagingSenderId',
        question: 'Please provide your Firebase iOS Messaging Sender ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_projectId',
        question: 'Please provide your Firebase iOS Project ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_storageBucket',
        question: 'Please provide your Firebase iOS Storage Bucket: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_authDomain',
        question: 'Please provide your Firebase iOS Auth Domain: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'web_apiKey',
        question: 'Please provide your Firebase Web API key: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_appId',
        question: 'Please provide your Firebase Web App ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_authDomain',
        question: 'Please provide your Firebase Web Auth Domain: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_messagingSenderId',
        question: 'Please provide your Firebase Web Messaging Sender ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_projectId',
        question: 'Please provide your Firebase Web Project ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_storageBucket',
        question: 'Please provide your Firebase Web Storage Bucket: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_measurementId',
        question: 'Please provide your Firebase Web Measurement ID: ',
        required: (args) => args.platform.includes('web'),
      },
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
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'alwaysUseLocationDescription',
        question:
          'Please provide a description for always using location services for network info: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'preciseLocationDescription',
        question:
          'Please provide a description for using precise location services for network info: ',
        required: (args) => args.platform.includes('ios'),
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
      {
        key: 'googleIOSClientId',
        question: 'Please provide your iOS client ID: ',
        required: false,
      },
      {
        key: 'googleAndroidClientId',
        question: 'Please provide your Android client ID: ',
        required: false,
      },
      {
        key: 'googleWebClientId',
        question: 'Please provide your Web client ID: ',
        required: false,
      },
      {
        key: 'googleServerClientId',
        question: 'Please provide your server client ID: ',
        required: false,
      },
      {
        key: 'android_apiKey',
        question: 'Please provide your Firebase Android API key: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_appId',
        question: 'Please provide your Firebase Android App ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_messagingSenderId',
        question: 'Please provide your Firebase Android Messaging Sender ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_projectId',
        question: 'Please provide your Firebase Android Project ID: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_storageBucket',
        question: 'Please provide your Firebase Android Storage Bucket: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'android_authDomain',
        question: 'Please provide your Firebase Android Auth Domain: ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'ios_apiKey',
        question: 'Please provide your Firebase iOS API key: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_appId',
        question: 'Please provide your Firebase iOS App ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_messagingSenderId',
        question: 'Please provide your Firebase iOS Messaging Sender ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_projectId',
        question: 'Please provide your Firebase iOS Project ID: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_storageBucket',
        question: 'Please provide your Firebase iOS Storage Bucket: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'ios_authDomain',
        question: 'Please provide your Firebase iOS Auth Domain: ',
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'web_apiKey',
        question: 'Please provide your Firebase Web API key: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_appId',
        question: 'Please provide your Firebase Web App ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_authDomain',
        question: 'Please provide your Firebase Web Auth Domain: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_messagingSenderId',
        question: 'Please provide your Firebase Web Messaging Sender ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_projectId',
        question: 'Please provide your Firebase Web Project ID: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_storageBucket',
        question: 'Please provide your Firebase Web Storage Bucket: ',
        required: (args) => args.platform.includes('web'),
      },
      {
        key: 'web_measurementId',
        question: 'Please provide your Firebase Web Measurement ID: ',
        required: (args) => args.platform.includes('web'),
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
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'bluetoothPeripheralDescription',
        question:
          'Please provide a description for using Bluetooth peripherals: ',
        required: (args) => args.platform.includes('ios'),
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
        required: (args) => args.platform.includes('ios'),
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
        required: (args) => args.platform.includes('ios'),
      },
      {
        key: 'androidGoogleMapsApiKey',
        question: 'Please provide your Google Maps API key for Android ',
        required: (args) => args.platform.includes('android'),
      },
      {
        key: 'webGoogleMapsApiKey',
        question: 'Please provide your Google Maps API key for Web ',
        required: (args) => args.platform.includes('web'),
      },
    ],
  },
];

// Custom Scripts (standalone Dart scripts)
export const scripts = [
  {
    name: 'generateKeystore',
    path: 'scripts/generate_keystore.dart',
    parameters: [
      {
        key: 'storePassword',
        question: 'Please provide the store password: ',
        required: true,
      },
      {
        key: 'keyPassword',
        question: 'Please provide the key password: ',
        required: true,
      },
      {
        key: 'keyAlias',
        question: 'Please provide the key alias: ',
        required: true,
      },
    ],
  },
];
