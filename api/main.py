from fastapi import FastAPI, Request
from pydantic import BaseModel
import joblib
import uuid
import datetime
import sqlite3  

app = FastAPI()
model = joblib.load("model/model.pkl")

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
                (prediction_id, data.feature1, data.feature2, prediction, datetime.datetime.now()))
    conn.commit()
    conn.close()

    return {"prediction": prediction, "id": prediction_id}