import argparse
from jinja_utils import render_template
import json


def main():
    # Register and read the arguments
    parser = argparse.ArgumentParser(
        description="Generate AndroidManifest.xml with specified permissions."
    )
    parser.add_argument("--has-camera", type=str, default="false")
    parser.add_argument('--has-notification', type=str, default='false')
    parser.add_argument("--has-file-manager", type=str, default="false")
    parser.add_argument("--has-auth", type=str, default="false")
    parser.add_argument("--has-contacts", type=str, default="false")
    parser.add_argument("--has-location", type=str, default="false")
    parser.add_argument("--has-deeplink", type=str, default="false")
    parser.add_argument('--use-test-key', type=str, default="false")
    parser.add_argument("--has-google-maps", type=str, default="false")
    parser.add_argument("--scheme", type=str)
    parser.add_argument("--links", type=str)

    args = parser.parse_args()

    if args.links:
        json_value = json.loads(args.links.replace("'", "\""))
        links = [str(val) for val in json_value]
    else:
        links = []

    render_template(
        "starter/android/app/src/main/AndroidManifest.xml",
        has_camera=args.has_camera.lower() == "true",
        has_file_manager=args.has_file_manager.lower() == "true",
        has_auth=args.has_auth.lower() == "true",
        has_contacts=args.has_contacts.lower() == "true",
        has_location=args.has_location.lower() == "true",
        has_deeplink=args.has_deeplink.lower() == "true",
        use_test_key=args.use_test_key.lower() == "true",
        has_notification=args.has_notification.lower() == "true",
        has_google_maps=args.has_google_maps.lower() == "true",
        scheme=args.scheme,
        links=links,
    )


if __name__ == "__main__":
    main()
