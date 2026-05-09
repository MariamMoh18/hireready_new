import os
import sys

# 1. Define BASE_DIR first
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 2. Add it to sys.path
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

# 3. Now perform imports
from app import create_app
from app.models import db, JobPosition, Skill
from app.utils.job_data import JOB_ROLES

app = create_app()

def populate_jobs():
    with app.app_context():
        print("⏳ Starting database population...")
        
        for key, data in JOB_ROLES.items():
            # Check if job already exists to avoid duplicates
            job = JobPosition.query.filter_by(title=data["title"]).first()
            
            if not job:
                job = JobPosition(
                    title=data["title"],
                    level=data["level"],
                    description=data["description"]
                )
                db.session.add(job)
                db.session.flush()  # This populates job.id without committing
                print(f"➕ Adding Job: {data['title']}")

                for s in data["skills"]:
                    skill = Skill(
                        name=s["name"], 
                        level=s["level"], 
                        job_position_id=job.id
                    )
                    db.session.add(skill)
            else:
                print(f"⏩ Job '{data['title']}' already exists. Skipping.")
        
        db.session.commit()
        print("✅ Database populated successfully!")

if __name__ == "__main__":
    populate_jobs()