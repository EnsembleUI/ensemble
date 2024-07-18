import firebase_admin
from firebase_admin import credentials, firestore
import subprocess
import argparse


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Add Private key for iOS signing.')

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


def check_and_update_firestore():
    db = firestore.client()

    doc_ref = db.collection('apps').document(
        args.app_id).collection('artifacts').document('buildConfig')
    doc = doc_ref.get()

    if doc.exists:
        private_key = doc.to_dict().get('applePrivateKey')

        if private_key is None:
            generation_command = "ssh-keygen -t rsa -b 2048 -m PEM -f private_key -q -N \"\""
            subprocess.run(generation_command, shell=True)

            # Read the generated private key from the file
            with open('private_key', 'r') as private_key_file:
                private_key = private_key_file.read()

            # Upload the generated private key to Firestore
            doc_ref.update({'applePrivateKey': private_key})

        subprocess.run(
            f'''
echo "CERTIFICATE_PRIVATE_KEY<<DELIMITER" >> $CM_ENV
echo "{private_key}" >> $CM_ENV
echo "DELIMITER" >> $CM_ENV
''',
            shell=True
        )


if __name__ == "__main__":
    args = parse_arguments()
    initialize_firebase()

    check_and_update_firestore()
