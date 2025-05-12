import sqlite3
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

# Connect to DB
conn = sqlite3.connect("db/predictions.db")

# Load predictions and feedback
preds_df = pd.read_sql_query("SELECT * FROM predictions", conn)
fb_df = pd.read_sql_query("SELECT * FROM feedback", conn)

# Merge feedback with predictions
merged = preds_df.merge(fb_df, left_on="id", right_on="prediction_id")

if merged.empty:
    print("⚠️ No feedback data available for retraining.")
else:
    print(f"📊 Retraining with {len(merged)} corrected samples.")

    # Prepare training data
    X = merged[["f1", "f2"]]
    y = merged["correct_label"]

    # Train new model
    clf = RandomForestClassifier()
    clf.fit(X, y)

    # Save model
    os.makedirs("model", exist_ok=True)
    joblib.dump(clf, "model/model.pkl")
    print("✅ Model retrained and saved.")

conn.close()
