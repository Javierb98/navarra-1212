"""Local dev server that tells the browser never to cache, so every reload
gets the current code. (Browsers can otherwise keep stale copies of the
game's ES modules, mixing old and new files after an update.)

Usage: python3 tools/serve.py [port]   (default 8000)
"""
import http.server
import os
import sys


class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Expires', '0')
        super().end_headers()


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f'Espadas de Hispania: http://localhost:{port}')
    http.server.ThreadingHTTPServer(('', port), NoCache).serve_forever()
