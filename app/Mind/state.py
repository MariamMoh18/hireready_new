from typing import TypedDict, List, Optional, Any

class InterviewState(TypedDict):
    session_id: int
    messages: List[dict]
    question_count: int
    max_questions: int
    current_question: Optional[str]
    pending_answer: Optional[str]
    is_finished: bool
    
    # Behavioral Keys
    master_baseline: Optional[dict] # Result from calibrate node
    current_behavioral_metrics: Optional[dict] # Passed from video pipeline
    current_answer_id: Optional[int] # To link feedback to DB
    
    # Job Info
    job_title: str
    job_level: str
    job_skills: List[str]

