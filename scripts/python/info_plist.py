import argparse
import ast
from jinja_utils import render_template


def add_default_string(variable, default_string="Default"):
    if variable is None or (isinstance(variable, str) and not variable.strip()):
        variable = default_string
    return variable


def main():
    default_string = "Requires this permission for some functionalities to work"

    parser = argparse.ArgumentParser(
        description="Generate Info.plist with specified permissions."
    )

    print("Running info.plist")

    parser.add_argument("--ios-app-name", type=str)
    parser.add_argument("--has-auth", type=str, default="false")
    parser.add_argument("--has-file-manager", type=str, default="false")
    parser.add_argument("--has-contacts", type=str, default="false")
    parser.add_argument("--has-connect", type=str, default="false")
    parser.add_argument("--has-camera", type=str, default="false")
    parser.add_argument("--has-location", type=str, default="false")
    parser.add_argument("--has-deeplink", type=str, default="false")
    parser.add_argument('--ios-client-id', required=True)
    parser.add_argument("--live-key", type=str)
    parser.add_argument("--test-key", type=str)
    parser.add_argument("--scheme", type=str)
    parser.add_argument("--links", type=str)
    parser.add_argument("--location-description", type=str)
    parser.add_argument("--music-description", type=str)
    parser.add_argument("--photo-library-description", type=str)
    parser.add_argument("--contacts-description", type=str)
    parser.add_argument("--camera-description", type=str)
    parser.add_argument("--in-use-location-description", type=str)
    parser.add_argument("--always-use-location-description", type=str)

    args = parser.parse_args()

    print(args.has_auth.lower() == "true")
    print(args.has_file_manager.lower() == "true")
    print(args.has_contacts.lower() == "true")
    print(args.has_connect.lower() == "true")
    print(args.has_location.lower() == "true")
    print(args.has_deeplink.lower() == "true")

    links_value = ast.literal_eval(args.links) if args.links else []

    render_template(
        "starter/ios/Runner/Info.plist",
        ios_app_name=args.ios_app_name.strip(),
        has_auth=args.has_auth.lower() == "true",
        has_file_manager=args.has_file_manager.lower() == "true",
        has_contacts=args.has_contacts.lower() == "true",
        has_connect=args.has_connect.lower() == "true",
        has_camera=args.has_camera.lower() == "true",
        has_location=args.has_location.lower() == "true",
        has_deeplink=args.has_deeplink.lower() == "true",
        live_key=args.live_key,
        test_key=args.test_key,
        scheme=args.scheme,
        links=links_value,
        ios_client_id=args.ios_client_id,
        location_description=add_default_string(args.location_description, default_string),
        music_description=add_default_string(args.music_description, default_string),
        photo_library_description=add_default_string(args.photo_library_description, default_string),
        contacts_description=add_default_string(args.contacts_description, default_string),
        camera_description=add_default_string(args.camera_description, default_string),
        in_use_location_description=add_default_string(args.in_use_location_description, default_string),
        always_use_location_description=add_default_string(args.always_use_location_description, default_string),
    )


if __name__ == "__main__":
    main()
