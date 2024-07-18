import argparse
import firebase_admin
from firebase_admin import credentials, storage


def file_exists(blob):
    try:
        return blob.exists()

    except Exception as e:
        return False


def get_assets(get_from_firebase, app_id):
    if get_from_firebase:
        icon = storage.bucket().blob(f'builds/{app_id}/icon.png')
        splash = storage.bucket().blob(f'builds/{app_id}/splash.png')
        splash_bg = storage.bucket().blob(f'builds/{app_id}/splash_bg.png')

        if file_exists(icon):
            icon.download_to_filename('starter/assets/icon/icon.png')

        if file_exists(splash):
            splash.download_to_filename('starter/assets/icon/splash.png')

        if file_exists(splash_bg):
            splash_bg.download_to_filename('starter/assets/icon/splash_bg.png')


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Fetch logo from firebase if defined.')

    parser.add_argument(
        '--get-from-firebase',
        type=str,
        default='false',
        help='Whether to import from firebase or not'
    )
    parser.add_argument('--app-id', required=True,
                        help='Ensemble Application id')
    parser.add_argument('--firebase-credentials', required=True,
                        help='Credentials for firebase')

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

    get_assets(
        args.get_from_firebase.lower() == 'true',
        args.app_id,
    )
