# add_columns.py
from sqlalchemy import create_engine, text
import os

engine = create_engine("sqlite:///" + os.path.abspath("instance/app.db"))

with engine.connect() as conn:
    try:
        conn.execute(text("ALTER TABLE interview_session ADD COLUMN session_type VARCHAR(20) DEFAULT 'standard'"))
        print("✅ Added session_type")
    except Exception as e:
        print(f"session_type: {e}")
    
    try:
        conn.execute(text("ALTER TABLE interview_session ADD COLUMN max_questions INTEGER DEFAULT 5"))
        print("✅ Added max_questions")
    except Exception as e:
        print(f"max_questions: {e}")

    try:
        conn.execute(text("ALTER TABLE interview_session ADD COLUMN master_baseline JSON"))
        print("✅ Added master_baseline")
    except Exception as e:
        print(f"master_baseline: {e}")

    try:
        conn.execute(text("ALTER TABLE answer ADD COLUMN word_timestamps JSON"))
        print("✅ Added word_timestamps")
    except Exception as e:
        print(f"word_timestamps: {e}")

    conn.commit()
    print("\n✅ Done")