import argparse
from jinja_utils import render_template


def add_slash(string):
    string = string.strip()
    if not string or string[0] != '/':
        string = '/' + string
    if not string or string[-1] != '/':
        string += '/'
    return string


def add_default_string(variable, default_string="Default"):
    if variable is None or (isinstance(variable, str) and not variable.strip()):
        variable = default_string
    return variable


def parse_args():
    parser = argparse.ArgumentParser(
        description='Update index.html file.'
    )

    parser.add_argument('--has-connect', type=str, default='false')
    parser.add_argument('--has-deeplink', type=str, default='false')
    parser.add_argument('--has-auth', type=str, default='false')
    parser.add_argument('--has-google-maps', type=str, default='false')

    parser.add_argument('--use-test-key', type=str, default='false')

    parser.add_argument("--live-key", type=str)
    parser.add_argument("--test-key", type=str)
    parser.add_argument("--google-maps-api-key", type=str)
    parser.add_argument('--web-client-id', required=True)

    parser.add_argument("--base-href", type=str)
    parser.add_argument('--description', type=str)
    parser.add_argument('--title', type=str)

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    render_template(
        "starter/web/index.html",
        has_connect=args.has_connect.lower() == "true",
        has_deeplink=args.has_deeplink.lower() == "true",
        has_auth=args.has_auth.lower() == "true",
        has_google_maps=args.has_google_maps.lower() == "true",
        use_test_key=args.use_test_key.lower() == "true",
        web_client_id=args.web_client_id,
        description=args.description,
        title=args.title,
        live_key=args.live_key,
        test_key=args.test_key,
        google_maps_api_key=args.google_maps_api_key,
        base_href=add_slash(args.base_href),
    )
