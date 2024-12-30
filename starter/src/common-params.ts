import { Parameter } from './interfaces';

export const firebaseAndroidParameters: Parameter[] = [
  {
    key: 'android_apiKey',
    question: 'Please provide your Firebase **Android** API key:',
    platform: ['android'],
    type: 'text',
  },
  {
    key: 'android_appId',
    question: 'Please provide your Firebase **Android** App ID:',
    platform: ['android'],
    type: 'text',
  },
  {
    key: 'android_messagingSenderId',
    question: 'Please provide your Firebase **Android** Messaging Sender ID:',
    platform: ['android'],
    type: 'text',
  },
  {
    key: 'android_projectId',
    question: 'Please provide your Firebase **Android** Project ID:',
    platform: ['android'],
    type: 'text',
  },
  {
    key: 'android_storageBucket',
    question: 'Please provide your Firebase **Android** Storage Bucket:',
    platform: ['android'],
    type: 'text',
  },
  {
    key: 'android_authDomain',
    question: 'Please provide your Firebase **Android** Auth Domain:',
    platform: ['android'],
    type: 'text',
  },
];

export const firebaseIOSParameters: Parameter[] = [
  {
    key: 'ios_apiKey',
    question: 'Please provide your Firebase **iOS** API key:',
    platform: ['ios'],
    type: 'text',
  },
  {
    key: 'ios_appId',
    question: 'Please provide your Firebase **iOS** App ID:',
    platform: ['ios'],
    type: 'text',
  },
  {
    key: 'ios_messagingSenderId',
    question: 'Please provide your Firebase **iOS** Messaging Sender ID:',
    platform: ['ios'],
    type: 'text',
  },
  {
    key: 'ios_projectId',
    question: 'Please provide your Firebase **iOS** Project ID:',
    platform: ['ios'],
    type: 'text',
  },
  {
    key: 'ios_storageBucket',
    question: 'Please provide your Firebase **iOS** Storage Bucket:',
    platform: ['ios'],
    type: 'text',
  },
  {
    key: 'ios_authDomain',
    question: 'Please provide your Firebase **iOS** Auth Domain:',
    platform: ['ios'],
    type: 'text',
  },
];

export const firebaseWebParameters: Parameter[] = [
  {
    key: 'web_apiKey',
    question: 'Please provide your Firebase **Web** API key:',
    platform: ['web'],
    type: 'text',
  },
  {
    key: 'web_appId',
    question: 'Please provide your Firebase **Web** App ID:',
    platform: ['web'],
    type: 'text',
  },
  {
    key: 'web_authDomain',
    question: 'Please provide your Firebase **Web** Auth Domain:',
    platform: ['web'],
    type: 'text',
  },
  {
    key: 'web_messagingSenderId',
    question: 'Please provide your Firebase **Web** Messaging Sender ID:',
    platform: ['web'],
    type: 'text',
  },
  {
    key: 'web_projectId',
    question: 'Please provide your Firebase **Web** Project ID:',
    platform: ['web'],
    type: 'text',
  },
  {
    key: 'web_storageBucket',
    question: 'Please provide your Firebase **Web** Storage Bucket:',
    platform: ['web'],
    type: 'text',
  },
  {
    key: 'web_measurementId',
    question: 'Please provide your Firebase **Web** Measurement ID:',
    platform: ['web'],
    type: 'text',
  },
];
