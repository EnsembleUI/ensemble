import argparse
from jinja_utils import render_template


def parse_args():
    parser = argparse.ArgumentParser(
        description='Update AppDelegate.swift file.'
    )

    parser.add_argument("--google-maps-api-key", type=str)
    parser.add_argument("--has-google-maps", type=str)

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    render_template(
        "starter/ios/Runner/AppDelegate.swift",
        has_google_maps=args.has_google_maps.lower() == "true",
        google_maps_api_key=args.google_maps_api_key,
    )
