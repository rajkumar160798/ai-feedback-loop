# 🤖 AI-in-the-Loop: Feedback-Based Retraining Pipeline

This project demonstrates how to build an end-to-end AI-in-the-loop system that learns from its own mistakes through a feedback loop, using:

- 🧠 FastAPI for real-time prediction and feedback
- ⏱️ Airflow for scheduled retraining
- 🧪 scikit-learn for model training
- 📈 SQLite for lightweight logging
- 📊 Jupyter notebook visualizations

---

## 🧱 Architecture

1. `POST /predict` — Predicts and logs the input
2. `POST /feedback` — Logs user/system feedback
3. Airflow retrains daily if new feedback is present
4. New model is saved and replaces the old one

---

## 📂 How to Run

```bash
# Step 1: Set up the database
sqlite3 db/predictions.db < db/schema.sql

# Step 2: Start FastAPI
uvicorn api.main:app --reload

# Step 3: Submit feedback
curl -X POST http://localhost:8000/feedback ...

# Step 4: Trigger Airflow DAG (manual or scheduler)
