import argparse
import os
import firebase_admin
from firebase_admin import credentials, storage


def get_assets(app_id, local_path, storage_folder):
    folder_ref = storage.bucket().list_blobs(
        prefix=f'builds/{app_id}/{storage_folder}/'
    )

    for blob in folder_ref:
        destination_file_path = os.path.join(
            local_path,
            os.path.basename(blob.name)
        )

        # Need to check this as the folder_ref also contains the local_path path
        if destination_file_path != local_path:
            os.makedirs(os.path.dirname(destination_file_path), exist_ok=True)
            blob.download_to_filename(destination_file_path)


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Fetch logo from firebase if defined.')

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

    get_assets(args.app_id, 'starter/ensemble/assets/', 'assets')
    get_assets(args.app_id, 'starter/ensemble/assets/fonts/', 'fonts')
