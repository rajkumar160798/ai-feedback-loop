import streamlit as st
import pandas as pd
import requests
import sqlite3
import os

st.set_page_config(page_title="AI Feedback Loop", layout="centered")

API_URL = "http://localhost:8000"

st.title("🤖 AI Feedback-Retraining Dashboard")

# ---- PREDICTION FORM ----
st.header("🔍 Make a Prediction")
with st.form("predict_form"):
    feature1 = st.number_input("Feature 1 (e.g., vibration)", value=0.5)
    feature2 = st.number_input("Feature 2 (e.g., temperature)", value=72.0)
    submit_pred = st.form_submit_button("Predict")

    if submit_pred:
        res = requests.post(f"{API_URL}/predict", json={
            "feature1": feature1,
            "feature2": feature2
        })
        if res.ok:
            result = res.json()
            st.success(f"Prediction: **{result['prediction']}**")
            st.code(f"Prediction ID: {result['id']}")
        else:
            st.error("Failed to get prediction")

# ---- VIEW PREDICTIONS ----
st.header("📋 Past Predictions")
conn = sqlite3.connect("db/predictions.db")
df_preds = pd.read_sql_query("SELECT * FROM predictions ORDER BY ts DESC LIMIT 10", conn)
st.dataframe(df_preds)

# ---- FEEDBACK FORM ----
st.header("📝 Submit Feedback")
with st.form("feedback_form"):
    pred_id = st.selectbox("Select a Prediction ID", df_preds["id"].tolist())
    correct_label = st.selectbox("Correct Label", [0, 1])
    comment = st.text_input("Comment (optional)")
    submit_feedback = st.form_submit_button("Submit Feedback")

    if submit_feedback:
        fb_res = requests.post(f"{API_URL}/feedback", json={
            "prediction_id": pred_id,
            "correct_label": correct_label,
            "comment": comment
        })
        if fb_res.ok:
            st.success("✅ Feedback submitted")
        else:
            st.error("❌ Failed to submit feedback")

# ---- RETRAINING ----
st.header("🔁 Retrain Model")
if st.button("Trigger Retraining"):
    os.system("python model/retrain_model.py")
    st.success("✅ Model retrained successfully")

conn.close()
