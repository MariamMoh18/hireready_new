import os
import json
from dotenv import load_dotenv
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI

from .state import InterviewState
from .prompts import INTERVIEWER_SYSTEM, FINAL_REPORT_SYSTEM

load_dotenv()

_llm = None

def get_llm():
    global _llm
    if _llm is None:
        _llm = ChatOpenAI(
            model="gpt-5-mini",
            temperature=0.4,
            api_key=os.environ.get("OPENAI_API_KEY")
        )
    return _llm

def _similarity(a: str, b: str) -> float:
    words_a = set(a.lower().split())
    words_b = set(b.lower().split())
    if not words_a or not words_b:
        return 0.0
    return len(words_a & words_b) / max(len(words_a), len(words_b))

def get_stage(question_count: int, max_questions: int) -> str:
    # progress-based stages (works for 4, 8, 13, etc.)
    if max_questions <= 0:
        return "early"
    p = question_count / max_questions
    if p < 0.25:
        return "early"
    if p < 0.85:
        return "middle"
    return "late"

def ask_question(state: InterviewState) -> dict:
    job_title = state.get("job_title") or "General Position"
    job_level = state.get("job_level") or ""
    job_skills = ", ".join(state.get("job_skills") or []) or "not specified"
    question_count = state.get("question_count", 0)
    max_questions = state.get("max_questions", 6)
    stage = get_stage(question_count, max_questions)
    print(f"DEBUG: stage={stage}, question_count={question_count}, max_questions={max_questions}")
    # full message history so far
    history = state.get("messages") or []

    # list of already asked questions to prevent repeats
    asked = [m["content"].strip() for m in history if m["role"] == "assistant"]
    asked_text = "\n".join(f"- {q}" for q in asked) if asked else "None"

    msgs = [{"role": "system", "content": INTERVIEWER_SYSTEM.format(
        job_title=job_title,
        job_level=job_level,
        job_skills=job_skills
    )}]
    msgs += history
    msgs.append({
        "role": "user",
        "content": (
            f"Questions already asked:\n{asked_text}\n\n"
            f"Current interview stage: {stage}.\n"
            f"Ask a NEW question #{question_count + 1} of {max_questions}.\n"
            f"Do NOT repeat any question above.\n"
            f"Adapt naturally to the stage:\n"
            f"- early: introduction, background, relevant experience\n"
            f"- middle: technical and behavioral depth\n"
            f"- late: situational, reflective, or closing questions\n"
            f"Output the question only."
        )
    })
    # retry up to 3 times if model repeats
    for attempt in range(3):
        q = get_llm().invoke(msgs).content.strip()
        is_repeat = any(_similarity(q, prev) > 0.7 for prev in asked)
        if not is_repeat:
            break
        print(f"(repeat detected, retrying... attempt {attempt + 1})")

    # append to existing messages — do NOT replace
    updated_messages = history + [{"role": "assistant", "content": q}]

    return {
        "current_question": q,
        "messages": updated_messages,        # full history preserved
    }

def build_graph():
    workflow = StateGraph(InterviewState)
    
    # Add nodes to the graph
    workflow.add_node("ask_question", ask_question)
    workflow.set_entry_point("ask_question")
    workflow.add_edge("ask_question", END)   # always pause after question
    return workflow.compile()