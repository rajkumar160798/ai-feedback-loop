from fastapi import FastAPI
from pydantic import BaseModel
import joblib
import uuid
import datetime
import sqlite3

app = FastAPI()
model = joblib.load("model/model.pkl")

# ----- PREDICTION ROUTE -----
class InputData(BaseModel):
    feature1: float
    feature2: float

@app.post("/predict")
def predict(data: InputData):
    prediction = model.predict([[data.feature1, data.feature2]])[0]
    prediction_id = str(uuid.uuid4())

    # Log prediction
    conn = sqlite3.connect("db/predictions.db")
    cur = conn.cursor()
    cur.execute("INSERT INTO predictions (id, f1, f2, pred, ts) VALUES (?, ?, ?, ?, ?)",
                (prediction_id, data.feature1, data.feature2, int(prediction), datetime.datetime.now()))
    conn.commit()
    conn.close()

    return {
        "prediction": int(prediction),  # ✅ convert to native Python int
        "id": prediction_id
    }


# ----- FEEDBACK ROUTE -----
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
