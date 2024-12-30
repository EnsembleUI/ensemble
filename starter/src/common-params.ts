import { Parameter } from './interfaces';
import { requiredForPlatform } from './utils';

export const firebaseAndroidParameters: Parameter[] = [
  {
    key: 'android_apiKey',
    question: 'Please provide your Firebase **Android** API key:',
    required: requiredForPlatform('android'),
    type: 'text',
  },
  {
    key: 'android_appId',
    question: 'Please provide your Firebase **Android** App ID:',
    required: requiredForPlatform('android'),
    type: 'text',
  },
  {
    key: 'android_messagingSenderId',
    question: 'Please provide your Firebase **Android** Messaging Sender ID:',
    required: requiredForPlatform('android'),
    type: 'text',
  },
  {
    key: 'android_projectId',
    question: 'Please provide your Firebase **Android** Project ID:',
    required: requiredForPlatform('android'),
    type: 'text',
  },
  {
    key: 'android_storageBucket',
    question: 'Please provide your Firebase **Android** Storage Bucket:',
    required: requiredForPlatform('android'),
    type: 'text',
  },
  {
    key: 'android_authDomain',
    question: 'Please provide your Firebase **Android** Auth Domain:',
    required: requiredForPlatform('android'),
    type: 'text',
  },
];

export const firebaseIOSParameters: Parameter[] = [
  {
    key: 'ios_apiKey',
    question: 'Please provide your Firebase **iOS** API key:',
    required: requiredForPlatform('ios'),
    type: 'text',
  },
  {
    key: 'ios_appId',
    question: 'Please provide your Firebase **iOS** App ID:',
    required: requiredForPlatform('ios'),
    type: 'text',
  },
  {
    key: 'ios_messagingSenderId',
    question: 'Please provide your Firebase **iOS** Messaging Sender ID:',
    required: requiredForPlatform('ios'),
    type: 'text',
  },
  {
    key: 'ios_projectId',
    question: 'Please provide your Firebase **iOS** Project ID:',
    required: requiredForPlatform('ios'),
    type: 'text',
  },
  {
    key: 'ios_storageBucket',
    question: 'Please provide your Firebase **iOS** Storage Bucket:',
    required: requiredForPlatform('ios'),
    type: 'text',
  },
  {
    key: 'ios_authDomain',
    question: 'Please provide your Firebase **iOS** Auth Domain:',
    required: requiredForPlatform('ios'),
    type: 'text',
  },
];

export const firebaseWebParameters: Parameter[] = [
  {
    key: 'web_apiKey',
    question: 'Please provide your Firebase **Web** API key:',
    required: requiredForPlatform('web'),
    type: 'text',
  },
  {
    key: 'web_appId',
    question: 'Please provide your Firebase **Web** App ID:',
    required: requiredForPlatform('web'),
    type: 'text',
  },
  {
    key: 'web_authDomain',
    question: 'Please provide your Firebase **Web** Auth Domain:',
    required: requiredForPlatform('web'),
    type: 'text',
  },
  {
    key: 'web_messagingSenderId',
    question: 'Please provide your Firebase **Web** Messaging Sender ID:',
    required: requiredForPlatform('web'),
    type: 'text',
  },
  {
    key: 'web_projectId',
    question: 'Please provide your Firebase **Web** Project ID:',
    required: requiredForPlatform('web'),
    type: 'text',
  },
  {
    key: 'web_storageBucket',
    question: 'Please provide your Firebase **Web** Storage Bucket:',
    required: requiredForPlatform('web'),
    type: 'text',
  },
  {
    key: 'web_measurementId',
    question: 'Please provide your Firebase **Web** Measurement ID:',
    required: requiredForPlatform('web'),
    type: 'text',
  },
];
