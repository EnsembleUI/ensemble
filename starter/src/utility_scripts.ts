import { Parameter, Script } from './interfaces';

// Common parameters available across scripts and modules
export const commonParameters: Parameter[] = [
  {
    key: 'platform',
    question: 'Which platform(s) are you targeting?',
    type: 'select',
    choices: ['ios', 'android', 'web'],
    platform: ['android', 'ios', 'web'],
  },
  {
    key: 'ensemble_version',
    question: 'Which version of ensemble are you using?',
    type: 'text',
    platform: ['android', 'ios', 'web'],
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
        platform: ['android'],
        type: 'text',
      },
      {
        key: 'keyPassword',
        question: 'Please provide the key password: ',
        platform: ['android'],
        type: 'text',
      },
      {
        key: 'keyAlias',
        question: 'Please provide the key alias: ',
        platform: ['android'],
        type: 'text',
      },
    ],
  },
];
