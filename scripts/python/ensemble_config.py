import argparse
from jinja_utils import render_template


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Update ensemble-config.yaml file.')

    parser.add_argument('--app-id', required=True)
    parser.add_argument('--ios-client-id', required=True)
    parser.add_argument('--android-client-id', required=True)
    parser.add_argument('--web-client-id', required=True)
    parser.add_argument('--server-client-id', required=True)

    args = parser.parse_args()

    render_template(
        "starter/ensemble/ensemble-config.yaml",
        app_id=args.app_id,
        ios_client_id=args.ios_client_id,
        android_client_id=args.android_client_id,
        web_client_id=args.web_client_id,
        server_client_id=args.server_client_id,
    )
