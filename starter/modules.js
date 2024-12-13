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
    }
];

// Modules (called with `enable` command)
export const modules = [
    {
        name: 'camera',
        path: 'scripts/modules/enable_camera.dart',
        parameters: [
            { key: 'qrcode_enabled', question: 'Do you want to enable QR code scanning? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true },
            { key: 'camera_description', question: 'Please provide a camera usage description for iOS: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'files',
        path: 'scripts/modules/enable_files.dart',
        parameters: [
            { key: 'photo_library_description', question: 'Please provide a description for accessing the photo library: ', required: (args) => args.platform.includes('ios') },
            { key: 'music_description', question: 'Please provide a description for accessing music files: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'contacts',
        path: 'scripts/modules/enable_contacts.dart',
        parameters: [
            { key: 'contacts_description', question: 'Please provide a description for accessing contacts: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'connect',
        path: 'scripts/modules/enable_connect.dart',
        parameters: [
            { key: 'camera_description', question: 'Please provide a camera usage description: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'location',
        path: 'scripts/modules/enable_location.dart',
        parameters: [
            { key: 'in_use_location_description', question: 'Please provide a description for using location services while the app is in use: ', required: (args) => args.platform.includes('ios') },
            { key: 'always_use_location_description', question: 'Please provide a description for using location services always: ', required: (args) => args.platform.includes('ios') },
            { key: 'always_and_when_in_use_location_description', question: 'Please provide a description for using location services always and when the app is in use: ', required: (args) => args.platform.includes('ios') },
            { key: 'google_maps', question: 'Are you enabling Google Maps? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true },
            { key: 'google_maps_api_key_ios', question: 'Please provide your Google Maps API key for iOS ', required: (args) => args.google_maps === true && args.platform.includes('ios') },
            { key: 'google_maps_api_key_android', question: 'Please provide your Google Maps API key for Android ', required: (args) => args.google_maps === true && args.platform.includes('android') },
            { key: 'google_maps_api_key_web', question: 'Please provide your Google Maps API key for Web ', required: (args) => args.google_maps === true && args.platform.includes('web') }
        ]
    },
    {
        name: 'deeplink',
        path: 'scripts/modules/enable_deeplink.dart',
        parameters: [
            { key: 'branch_live_key', question: 'Please provide the live Branch.io key: ', required: true },
            { key: 'branch_test_key', question: 'Please provide the test Branch.io key: ', required: true },
            { key: 'use_test_key', question: 'Are you using the test key? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true },
            { key: 'scheme', question: 'Please provide the URI scheme for deeplinking: ', required: true },
            { key: 'links', question: 'Please provide a comma-separated list of deeplink URLs: ', required: true }
        ]
    },
    {
        name: 'firebaseAnalytics',
        path: 'scripts/modules/enable_firebase_analytics.dart',
        parameters: [
            { key: 'android_api_key', question: 'Please provide your Firebase Android API key: ', required: (args) => args.platform.includes('android') },
            { key: 'android_app_id', question: 'Please provide your Firebase Android App ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_messaging_sender_id', question: 'Please provide your Firebase Android Messaging Sender ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_project_id', question: 'Please provide your Firebase Android Project ID: ', required: (args) => args.platform.includes('android') },
            { key: 'ios_api_key', question: 'Please provide your Firebase iOS API key: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_app_id', question: 'Please provide your Firebase iOS App ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_messaging_sender_id', question: 'Please provide your Firebase iOS Messaging Sender ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_project_id', question: 'Please provide your Firebase iOS Project ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'web_api_key', question: 'Please provide your Firebase Web API key: ', required: (args) => args.platform.includes('web') },
            { key: 'web_app_id', question: 'Please provide your Firebase Web App ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_auth_domain', question: 'Please provide your Firebase Web Auth Domain: ', required: (args) => args.platform.includes('web') },
            { key: 'web_messaging_sender_id', question: 'Please provide your Firebase Web Messaging Sender ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_project_id', question: 'Please provide your Firebase Web Project ID: ', required: (args) => args.platform.includes('web') },
            { key: 'web_storage_bucket', question: 'Please provide your Firebase Web Storage Bucket: ', required: (args) => args.platform.includes('web') },
            { key: 'web_measurement_id', question: 'Please provide your Firebase Web Measurement ID: ', required: (args) => args.platform.includes('web') },
            { key: 'enable_console_logs', question: 'Do you want to enable Firebase console logs? (yes/no): ', type: 'list', choices: ['yes', 'no'], required: true }
        ]
    },
    {
        name: 'notifications',
        path: 'scripts/modules/enable_notifications.dart',
        parameters: [
            { key: 'android_api_key', question: 'Please provide your Firebase Android API key: ', required: (args) => args.platform.includes('android') },
            { key: 'android_app_id', question: 'Please provide your Firebase Android App ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_messaging_sender_id', question: 'Please provide your Firebase Android Messaging Sender ID: ', required: (args) => args.platform.includes('android') },
            { key: 'android_project_id', question: 'Please provide your Firebase Android Project ID: ', required: (args) => args.platform.includes('android') },
            { key: 'ios_api_key', question: 'Please provide your Firebase iOS API key: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_app_id', question: 'Please provide your Firebase iOS App ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_messaging_sender_id', question: 'Please provide your Firebase iOS Messaging Sender ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'ios_project_id', question: 'Please provide your Firebase iOS Project ID: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'bracket',
        path: 'scripts/modules/enable_bracket.dart',
        parameters: []  // Bracket doesn't need any special parameters
    },
    {
        name: 'networkInfo',
        path: 'scripts/modules/enable_network_info.dart',
        parameters: [
            { key: 'in_use_location_description', question: 'Please provide a description for using location services while accessing network info: ', required: (args) => args.platform.includes('ios') },
            { key: 'always_location_description', question: 'Please provide a description for always using location services for network info: ', required: (args) => args.platform.includes('ios') },
            { key: 'precise_location_description', question: 'Please provide a description for using precise location services for network info: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'chat',
        path: 'scripts/modules/enable_chat.dart',
        parameters: [] // Chat is a UI widget without special parameters needed
    },
    {
        name: 'auth',
        path: 'scripts/modules/enable_auth.dart',
        parameters: [
            { key: 'ios_client_id', question: 'Please provide your iOS client ID: ', required: (args) => args.platform.includes('ios') },
            { key: 'android_client_id', question: 'Please provide your Android client ID: ', required: (args) => args.platform.includes('android') },
            { key: 'web_client_id', question: 'Please provide your Web client ID: ', required: (args) => args.platform.includes('web') },
            { key: 'server_client_id', question: 'Please provide your server client ID: ', required: true }
        ]
    },
    {
        name: 'bluetooth',
        path: 'scripts/modules/enable_bluetooth.dart',
        parameters: [
            { key: 'bluetooth_description', question: 'Please provide a description for accessing Bluetooth: ', required: (args) => args.platform.includes('ios') },
            { key: 'bluetooth_peripheral_description', question: 'Please provide a description for using Bluetooth peripherals: ', required: (args) => args.platform.includes('ios') }
        ]
    },
    {
        name: 'biometric',
        path: 'scripts/modules/enable_biometric.dart',
        parameters: [
            { key: 'face_id_description', question: 'Please provide a description for Face ID usage (iOS): ', required: (args) => args.platform.includes('ios') }
        ]
    }
];

// Custom Scripts (standalone Dart scripts)
export const scripts = [
    {
        name: 'generateKeystore',
        path: 'scripts/generate_keystore.dart',
        parameters: [
            { key: 'storePassword', question: 'Please provide the store password: ', required: true },
            { key: 'keyPassword', question: 'Please provide the key password: ', required: true },
            { key: 'keyAlias', question: 'Please provide the key alias: ', required: true }
        ]
    },
    {
        name: 'getShaKeys',
        path: 'scripts/get_sha_keys.dart',
        parameters: []
    }
];
