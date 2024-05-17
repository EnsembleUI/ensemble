import http.server
from http.server import HTTPServer, SimpleHTTPRequestHandler
import mimetypes

class CustomHTTPRequestHandler(SimpleHTTPRequestHandler):
    def guess_type(self, path):
        if path.endswith('.ensemble'):
            return 'text/yaml'
        return super().guess_type(path)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'X-Requested-With')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

if __name__ == '__main__':
    PORT = 8000
    handler = CustomHTTPRequestHandler
    httpd = HTTPServer(("", PORT), handler)

    print(f"Serving at port {PORT}")
    httpd.serve_forever()

