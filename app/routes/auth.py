from flask.views import MethodView
from flask_smorest import Blueprint, abort
from flask_jwt_extended import (
    create_access_token, 
    jwt_required, 
    get_jwt_identity, 
    get_jwt
)
from ..models import db, User, TokenBlocklist
from ..schemas import UserSchema, UserRegisterSchema, UserLoginSchema, UserUpdateSchema

auth_bp = Blueprint("auth", __name__, description="Operations on authentication")

@auth_bp.route("/register")
class UserRegister(MethodView):
    @auth_bp.arguments(UserRegisterSchema)
    @auth_bp.response(201, UserSchema)
    def post(self, user_data):
        # `user_data` includes a plaintext password that is not a User model field.
        # Build the model instance manually so password hashing is explicit and safe.
        if User.query.filter_by(email=user_data["email"]).first():
            abort(409, message="A user with that email already exists.")
        raw_password = user_data.get("password")
        if not raw_password:
            abort(400, message="Password is required.")

        user = User(
            name=user_data["name"],
            email=user_data["email"]
        )
        user.set_password(raw_password)

        try:
            db.session.add(user)
            db.session.commit()
        except Exception as e:
            db.session.rollback()
            abort(500, message=f"Database error: {str(e)}")

        return user


@auth_bp.route("/login")
class UserLogin(MethodView):
    @auth_bp.arguments(UserLoginSchema)
    def post(self, login_data):
        user = User.query.filter_by(email=login_data["email"]).first()

        if user and user.check_password(login_data["password"]):
            # Create token with user ID
            access_token = create_access_token(identity=str(user.id))
            
            # Use the UserSchema to dump user data properly for Flutter
            return {
                "access_token": access_token, 
                "user": UserSchema().dump(user)
            }, 200

        abort(401, message="Invalid credentials.")


@auth_bp.route("/logout")
class UserLogout(MethodView):
    @jwt_required()
    def post(self):
        jti = get_jwt()["jti"]
        try:
            new_blocked_token = TokenBlocklist(jti=jti)
            db.session.add(new_blocked_token)
            db.session.commit()
            return {"message": "Successfully logged out"}, 200
        except Exception:
            db.session.rollback()
            abort(500, message="Logout failed.")


@auth_bp.route("/profile")
class UserProfile(MethodView):
    @jwt_required()
    @auth_bp.response(200, UserSchema)
    @auth_bp.arguments(UserUpdateSchema)
    def patch(self, update_data):
        current_user_id = get_jwt_identity()
        user = db.session.get(User, int(current_user_id))

        if not user:
            abort(404, message="User not found.")

        for key, value in update_data.items():
            setattr(user, key, value)

        try:
            db.session.commit()
        except Exception:
            db.session.rollback()
            abort(500, message="Update failed.")

        return user


@auth_bp.route("/me")
class AuthMe(MethodView):
    @jwt_required()
    def get(self):
        user_id = int(get_jwt_identity())
        user = db.session.get(User, user_id)
        if not user:
            abort(404, message="User not found.")

        completed_interviews = sum(1 for session in user.sessions if session.status == "completed")

        return {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "experience_level": user.experience_level,
            "total_interviews": completed_interviews,
            "joined_at": user.created_at.strftime("%Y-%m-%d"),
        }, 200
