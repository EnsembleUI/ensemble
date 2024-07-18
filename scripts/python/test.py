import argparse
import os
import re
import firebase_admin
from firebase_admin import credentials, firestore


def normalize_name(name):
    return re.sub(r'[^\w\s]', '', name.strip().replace(' ', '_')).lower() + '.yaml'


def fetch_documents(app_id):
    artifacts_ref = db.collection('apps').document(app_id).collection(
        'artifacts').where('type', '==', 'test').stream()

    for artifact in artifacts_ref:
        artifact_data = artifact.to_dict()
        name = artifact_data.get('name')
        content = artifact_data.get('content')

        file_name = normalize_name(name)

        if file_name and content:
            file_path = os.path.join('.maestro', file_name)
            with open(file_path, 'w') as file:
                file.write(content)


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Fetch documents from Firestore based on type attribute.')

    parser.add_argument('--app-id', required=True,
                        help='Ensemble Application id')
    parser.add_argument('--firebase-credentials', required=True,
                        help='Credentials for Firebase')

    return parser.parse_args()


def initialize_firebase():
    with open('serviceAccountKey.json', 'w') as file:
        file.write(args.firebase_credentials)

    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)


if __name__ == "__main__":
    args = parse_arguments()
    initialize_firebase()
    db = firestore.client()

    fetch_documents(args.app_id)
