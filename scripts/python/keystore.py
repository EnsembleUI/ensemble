import argparse
import subprocess
import firebase_admin
from firebase_admin import credentials, storage


def file_exists(blob):
    try:
        return blob.exists()

    except Exception as e:
        return False


def generate_keystore(generate_keystore, app_id, keystore_password, key_alias, key_password):
    try:
        jks_blob = storage.bucket().blob(
            f'builds/{app_id}/keystore.jks')
        keystore_blob = storage.bucket().blob(
            f'builds/{app_id}/key.keystore')

        if not generate_keystore and (file_exists(jks_blob) or file_exists(keystore_blob)):
            if file_exists(jks_blob):
                jks_blob.download_to_filename('android/app/keystore.jks')
            else:
                keystore_blob.download_to_filename(
                    'starter/android/app/key.keystore')
        else:
            subprocess.run([
                'keytool',
                '-genkeypair',
                '-keystore', 'android/app/keystore.jks',
                '-storepass', keystore_password,
                '-keypass', key_password,
                '-alias', key_alias,
                '-validity', "3650",
                '-keysize', "2048",
                '-dname', 'CN=, OU=, O=, L=, ST=, C=',
                '-keyalg', 'RSA'
            ], check=True)

            jks_blob = storage.bucket().blob(f'builds/{app_id}/keystore.jks')
            jks_blob.upload_from_filename('starter/android/app/keystore.jks')

        if file_exists(jks_blob):
            key_properties = f'storePassword={keystore_password}\nkeyPassword={key_password}\nkeyAlias={key_alias}\nstoreFile=keystore.jks'
        else:
            key_properties = f'storePassword={keystore_password}\nkeyPassword={key_password}\nkeyAlias={key_alias}\nstoreFile=key.keystore'

        with open('starter/android/key.properties', 'w') as key_file:
            key_file.write(key_properties)

    except subprocess.CalledProcessError as e:
        print(f'Error generating keystore: {e}')


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Generate a keystore using keytool command.')

    parser.add_argument(
        '--generate-keystore',
        type=str,
        default='false',
        help='Whether to import from firebase or not'
    )
    parser.add_argument('--app-id', required=True,
                        help='Ensemble Application id')
    parser.add_argument('--firebase-credentials', required=True,
                        help='Credentials for firebase')
    parser.add_argument('--keystore-password', required=True,
                        help='Password for the keystore')
    parser.add_argument('--key-alias', required=True,
                        help='Alias for the key pair')
    parser.add_argument('--key-password', required=True,
                        help='Password for the key pair')

    return parser.parse_args()


def initialize_firebase():
    with open('serviceAccountKey.json', 'w') as file:
        file.write(args.firebase_credentials)

    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(
        cred,
        {'storageBucket': 'ensemble-web-studio.appspot.com'}
    )


if __name__ == "__main__":
    args = parse_arguments()
    initialize_firebase()

    generate_keystore(
        args.generate_keystore.lower() == 'true',
        args.app_id,
        args.keystore_password,
        args.key_alias,
        args.key_password
    )
