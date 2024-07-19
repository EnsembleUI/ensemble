import argparse
import subprocess
import os
def check_and_change_directory():
    current_dir = os.path.basename(os.getcwd())
    if current_dir != "starter":
        starter_dir = os.path.join(os.getcwd(), "starter")

        # Print out the list of directories under the current directory
        print(f"Current directory: {os.getcwd()}")
        print("Directories under the current directory:")
        for item in os.listdir(os.getcwd()):
            if os.path.isdir(os.path.join(os.getcwd(), item)):
                print(item)

        if os.path.exists(starter_dir) and os.path.isdir(starter_dir):
            os.chdir(starter_dir)
        else:
            raise FileNotFoundError(f"'starter' directory not found in the current directory {os.getcwd()}.")



def create_flutter_project(package_name, platform):
    namespace = ".".join(package_name.split('.')[:-1])
    project_name = package_name.split('.')[-1]

    subprocess.run(["flutter", "create", "--org", namespace,
                   "--project-name", project_name, "--platform=" + platform, "."])


def main():
    print(f"before Current directory: {os.getcwd()}")
    check_and_change_directory()
    print(f"after Current directory: {os.getcwd()}")
    parser = argparse.ArgumentParser(
        description="Create Flutter projects for Android, iOS and web platforms.")
    parser.add_argument("--android-package-name", required=True)
    parser.add_argument("--ios-package-name", required=True)
    parser.add_argument("--build-name", required=True)

    args = parser.parse_args()

    build_name = args.build_name.lower()

    if "project" in build_name:
        create_flutter_project(args.android_package_name, "android")
        create_flutter_project(args.ios_package_name, "ios")
        subprocess.run(["flutter", "create", "--platform=web", "."])

    if "apk" in build_name or "app bundle" in build_name:
        create_flutter_project(args.android_package_name, "android")

    if "ipa" in build_name:
        create_flutter_project(args.ios_package_name, "ios")

    if "web" in build_name:
        subprocess.run(["flutter", "create", "--platform=web", "."])
    print(f"all done Current directory: {os.getcwd()}")
    print("all done Directories under the current directory:")
    for item in os.listdir(os.getcwd()):
        if os.path.isdir(os.path.join(os.getcwd(), item)):
            print(item)

if __name__ == "__main__":
    main()
