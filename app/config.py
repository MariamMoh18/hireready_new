import os

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
INSTANCE_PATH = os.path.join(BASE_DIR, "..", "instance")
os.makedirs(INSTANCE_PATH, exist_ok=True)

class Config:
    #Database and security
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "super-secret-jwt")
    JWT_ACCESS_TOKEN_EXPIRES = 60 * 60 * 24  # 24 hours
    JWT_REFRESH_TOKEN_EXPIRES = 60 * 60 * 24 * 30  # 30 days
    SQLALCHEMY_DATABASE_URI = (
        "sqlite:///" +
        os.path.join(INSTANCE_PATH, "app.db")
    )

    SQLALCHEMY_TRACK_MODIFICATIONS = False

    SQLALCHEMY_ENGINE_OPTIONS = {
        "connect_args": {
            "check_same_thread": False
        },
        "pool_pre_ping": True
    }
    
    #  File Handling 
    MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50MB Limit
    UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
    
    # Flask-Smorest Settings
    API_TITLE = "Interview Simulator API"
    API_VERSION = "v1"
    OPENAPI_VERSION = "3.0.3"
    OPENAPI_URL_PREFIX = "/"
    OPENAPI_SWAGGER_UI_PATH = "/swagger-ui"  #use swagger for api documentation 
    OPENAPI_SWAGGER_UI_URL = "https://cdn.jsdelivr.net/npm/swagger-ui-dist/" #load swagger code 
    
    #  Tells Smorest where to put the JSON file
    OPENAPI_JSON_PATH = "openapi.json" 
    
    # Ensures errors are visible in your terminal during development
    PROPAGATE_EXCEPTIONS = True
    API_SPEC_OPTIONS = {
        "security": [{"bearerAuth": []}],
        "components": {
            "securitySchemes": {
                "bearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "JWT",
                }
            }
        },
    }
