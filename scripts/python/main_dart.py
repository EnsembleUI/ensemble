import argparse
from jinja_utils import render_template


def parse_args():
    parser = argparse.ArgumentParser(
        description='Update main.dart file.'
    )

    parser.add_argument('--has-notification', type=str, default='false')

    parser.add_argument("--notification-app-id", type=str)
    parser.add_argument("--notification-api-key", type=str)
    parser.add_argument("--notification-project-id", type=str)
    parser.add_argument("--notification-sender-id", type=str)

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    render_template(
        "starter/lib/main.dart",
        has_notification=args.has_notification.lower() == "true",
        notification_app_id=args.notification_app_id,
        notification_api_key=args.notification_api_key,
        notification_project_id=args.notification_project_id,
        notification_sender_id=args.notification_sender_id,
    )
