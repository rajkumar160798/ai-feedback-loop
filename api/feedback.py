from fastapi import FastAPI
from pydantic import BaseModel
import sqlite3
import datetime

app = FastAPI()

class Feedback(BaseModel):
    prediction_id: str
    correct_label: int
    comment: str = ""

@app.post("/feedback")
def collect_feedback(fb: Feedback):
    conn = sqlite3.connect("db/predictions.db")
    cur = conn.cursor()
    cur.execute("INSERT INTO feedback (prediction_id, correct_label, comment, ts) VALUES (?, ?, ?, ?)",
                (fb.prediction_id, fb.correct_label, fb.comment, datetime.datetime.now()))
    conn.commit()
    conn.close()
    return {"status": "Feedback received"}