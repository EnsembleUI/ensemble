import os
import argparse
from jinja_utils import render_template
import json


def add_default_string(variable, default_string="Default"):
    if variable is None or (isinstance(variable, str) and not variable.strip()):
        variable = default_string
    return variable


def parse_args():
    parser = argparse.ArgumentParser(
        description='Update pubspec.yaml file.'
    )

    parser.add_argument('--has-camera', type=str, default='false')
    parser.add_argument('--has-file-manager', type=str, default='false')
    parser.add_argument('--has-connect', type=str, default='false')
    parser.add_argument('--has-auth', type=str, default='false')
    parser.add_argument('--has-contacts', type=str, default='false')
    parser.add_argument('--has-location', type=str, default='false')
    parser.add_argument('--has-deeplink', type=str, default='false')

    parser.add_argument('--version', type=str)
    parser.add_argument('--splash-color', type=str)
    parser.add_argument('--splash-has-bg-image', type=str, default='false')
    parser.add_argument('--splash-has-icon', type=str, default='true')
    parser.add_argument("--build-name", required=True)

    parser.add_argument('--fonts', type=str)

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    fonts = json.loads(args.fonts.replace("'", "\"")) if args.fonts else {}

    build_name = args.build_name.lower()

    has_android = False
    has_ios = False
    has_web = False

    if "project" in build_name:
        has_android = True
        has_ios = True
        has_web = True

    if "apk" in build_name or "app bundle" in build_name:
        has_android = True

    if "ipa" in build_name:
        has_ios = True

    if "web" in build_name:
        has_web = True

    render_template(
        "starter/pubspec.yaml",
        has_auth=args.has_auth.lower() == "true",
        has_file_manager=args.has_file_manager.lower() == "true",
        has_contacts=args.has_contacts.lower() == "true",
        has_connect=args.has_connect.lower() == "true",
        has_camera=args.has_camera.lower() == "true",
        has_location=args.has_location.lower() == "true",
        has_deeplink=args.has_deeplink.lower() == "true",
        version=args.version,
        splash_color=add_default_string(args.splash_color, "#ffffff"),
        splash_has_bg_image=args.splash_has_bg_image.lower() == "true",
        splash_has_icon=args.splash_has_icon.lower() == "true",
        fonts=fonts,
        has_android=str(has_android).lower(),
        has_ios=str(has_ios).lower(),
        has_web=str(has_web).lower(),
    )
