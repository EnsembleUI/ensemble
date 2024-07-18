import argparse


def write_to_properties_file(filename, properties):
    with open(filename, 'a') as file:
        for key, value in properties.items():
            file.write(f"{key}={value}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Generate ensemble.properties file with specified values.")
    parser.add_argument(
        "--android-package-name",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--android-app-name",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--google-maps-api-key",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--auth0-domain",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--auth0-scheme",
        type=str,
        required=True,
    )

    parser.add_argument(
        "--test-key",
        type=str,
        required=True,
    )
    parser.add_argument(
        "--live-key",
        type=str,
        required=True,
    )

    args = parser.parse_args()
    properties = {
        "appId": args.android_package_name,
        "appName": args.android_app_name,
        "googleMapsAPIKey": args.google_maps_api_key,
        "auth0Domain": args.auth0_domain,
        "auth0Scheme": args.auth0_scheme,
        "branchTestKey": args.test_key,
        "branchLiveKey": args.live_key,
    }

    write_to_properties_file("starter/ensemble/ensemble.properties", properties)


if __name__ == "__main__":
    main()
