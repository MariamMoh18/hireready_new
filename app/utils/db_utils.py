from contextlib import contextmanager
from app.models import db

@contextmanager
def session_scope():
    """
    Provide a transactional scope around a series of operations.
    This ensures that the session is automatically committed, 
    rolled back on error, and closed at the end.
    """
    session = db.session
    try:
        yield session
        # If the code inside the 'with' block finishes successfully:
        session.commit()
    except Exception as e:
        # If any error occurs inside the 'with' block:
        session.rollback()
        print(f"❌ [DB_UTILS] Transaction rolled back due to error: {e}")
        raise
    finally:
        # Crucial for preventing memory leaks and connection pool exhaustion,
        # especially when used in background threads.
        session.close()