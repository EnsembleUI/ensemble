import argparse
import subprocess
import os


def get_default_keystore():
    if os.path.exists("starter/android/app/keystore.jks"):
        return "starter/android/app/keystore.jks"
    elif os.path.exists("key.keystore"):
        return "key.keystore"
    else:
        return None


def get_keytool_output(alias, password, keystore):
    command = [
        "keytool", "-list", "-v",
        "-alias", alias,
        "-keystore", keystore,
        "-storepass", password
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    return result.stdout


def extract_keys(output):
    sha1 = None
    sha256 = None
    lines = output.split("\n")
    for line in lines:
        if "SHA1" in line:
            sha1 = line
        elif "SHA256" in line:
            sha256 = line

        if sha1 and sha256:
            break

    return sha1, sha256


def save_keys_to_file(sha1, sha256):
    with open("keys.txt", "w") as f:
        f.write(sha1.strip())
        f.write('\n')
        f.write(sha256.strip())


def main():
    parser = argparse.ArgumentParser(
        description="Extract SHA1 and SHA256 keys from a keystore.")
    parser.add_argument("--alias", help="The alias of the keystore.")
    parser.add_argument("--password", help="The password of the keystore.")
    args = parser.parse_args()

    keystore = get_default_keystore()
    if not keystore:
        print("No keystore file found.")
        return

    output = get_keytool_output(args.alias, args.password, keystore)
    sha1, sha256 = extract_keys(output)

    if sha1 and sha256:
        save_keys_to_file(sha1, sha256)
    else:
        print("Failed to extract keys from keytool output.")


if __name__ == "__main__":
    main()
