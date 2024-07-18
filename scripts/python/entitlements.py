import argparse
import ast
from jinja_utils import render_template


def parse_args():
    parser = argparse.ArgumentParser(
        description='Update Runner.entitlements file.'
    )

    parser.add_argument('--has-deeplink', type=str, default='false')
    parser.add_argument("--links", type=str)

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    links_value = ast.literal_eval(args.links) if args.links else []

    render_template(
        "starter/ios/Runner/Runner.entitlements",
        has_deeplink=args.has_deeplink.lower() == "true",
        links=links_value,
    )
