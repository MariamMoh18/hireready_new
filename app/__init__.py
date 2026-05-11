import os
from pathlib import Path
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from dotenv import load_dotenv
from flask_migrate import Migrate
from flask_smorest import Api

from .schemas import ma
from .config import Config
from .models import db, TokenBlocklist

dotenv_path = Path(__file__).resolve().parent.parent / '.env'
load_dotenv(dotenv_path=dotenv_path)

def create_app():
    # Set instance_path explicitly to point to your 'instance' folder
    app = Flask(__name__, instance_relative_config=True)
    
    # Update SQLALCHEMY_DATABASE_URI to ensure it finds the existing app.db
    # This prevents the "OperationalError: unable to open database file"
    basedir = os.path.abspath(os.path.dirname(__file__))
    db_path = os.path.join(basedir, '..', 'instance', 'app.db')
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
    
    app.config.from_object(Config)

    # Initialize Extensions
    CORS(app)
    db.init_app(app)
    ma.init_app(app)
    migrate = Migrate(app, db)
    
    # Initialize JWT
    jwt = JWTManager(app)

    @jwt.token_in_blocklist_loader
    def check_if_token_revoked(jwt_header, jwt_payload):
        jti = jwt_payload["jti"]
        token = db.session.query(TokenBlocklist.id).filter_by(jti=jti).scalar()
        return token is not None

    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        return jsonify({"msg": "Token has expired", "message": "Token has expired", "code": 401}), 401

    @jwt.invalid_token_loader
    def invalid_token_callback(error):
        return jsonify({"msg": "Invalid token", "message": "Invalid token", "code": 422}), 422

    @jwt.unauthorized_loader
    def missing_token_callback(error):
        return jsonify({"msg": "Missing Authorization Header", "message": "Missing Authorization Header", "code": 401}), 401

    # Initialize Smorest Api
    api = Api(app)

    # Register Blueprints
    from .routes.auth import auth_bp
    from .routes.dashboard import dashboard_bp
    from .routes.reports import reports_bp
    from .routes.sessions import sessions_bp

    api.register_blueprint(auth_bp)
    api.register_blueprint(dashboard_bp)
    api.register_blueprint(reports_bp)
    api.register_blueprint(sessions_bp)

    @app.get("/health")
    def health():
        return jsonify({"status": "ok", "message": "Backend is running"})
    
    @app.route("/")
    def home():
        return "Interview Simulator Server Running!"

    return app
