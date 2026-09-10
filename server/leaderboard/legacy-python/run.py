"""Production HTTP entry point. Put HTTPS termination in front of this process."""
import os
from waitress import serve
from app import create_app

if __name__ == '__main__':
    application = create_app()
    serve(application, host=os.environ.get('HOST', '127.0.0.1'),
          port=int(os.environ.get('PORT', '8787')), threads=4,
          max_request_body_size=8192, max_request_header_size=32768,
          channel_timeout=30, expose_tracebacks=False)
