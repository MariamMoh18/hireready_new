import os
import torch
from flask_jwt_extended import create_access_token
from app import create_app
from app.models import db, User, InterviewSession, InterviewQuestion, Answer, Feedback, Score, JobPosition

def setup_minimal_data():
    """Ensures necessary foreign keys exist."""
    # Create a JobPosition first (Session needs this)
    job = JobPosition(title="Software Engineer", description="Test", level="Junior")
    db.session.add(job)
    db.session.commit()

    user = User(name="Test User", email="test@example.com")
    user.set_password("password123")
    db.session.add(user)
    db.session.commit()

    session = InterviewSession(user_id=user.id, job_position_id=job.id) 
    db.session.add(session)
    db.session.commit()

    question = InterviewQuestion(question_text="Tell me about yourself", session_id=session.id)
    db.session.add(question)
    db.session.commit()

    return user, session, question

def test_pipeline_to_db():
    app = create_app()
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///test_results.db'
    app.config['TESTING'] = True
    # Ensure this matches whatever is in your Config or .env
    app.config['JWT_SECRET_KEY'] = os.getenv("JWT_SECRET_KEY", "super-secret-key") 

    with app.app_context():
        db.drop_all()
        db.create_all()
        
        print("--- Setting up Data ---")
        user, session, question = setup_minimal_data()

        # Generate Token
        token = create_access_token(identity=str(user.id))
        headers = {'Authorization': f'Bearer {token}'}

        video_path = "images/Professional IT Interview Simulation_720p_caption.mp4"

        with app.test_client() as client:
            with open(video_path, 'rb') as video_file:
                data = {
                    'video': (video_file, 'test.mp4'),
                    'session_id': session.id,
                    'question_id': question.id
                }
                
                # --- THE FIX IS HERE ---
                target_url = '/api/analyze' 
                
                print(f"--- Sending Request to {target_url} ---")
                response = client.post(target_url, 
                                     data=data, 
                                     headers=headers, 
                                     content_type='multipart/form-data')

        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            res_json = response.get_json()
            print(f"Response: {res_json['status']}")
            
            # Verify DB
            ans = Answer.query.filter_by(session_id=session.id).first()
            if ans:
                print(f" DB SUCCESS: Found Answer ID {ans.id}")
                print(f"Confidence: {ans.facial_confidence}% | Stress: {ans.stress_level}%")
        else:
            print(f" FAILED: {response.get_json()}")

if __name__ == "__main__":
    test_pipeline_to_db()