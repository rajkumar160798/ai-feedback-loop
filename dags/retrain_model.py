from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import sqlite3
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

default_args = {
    'owner': 'myakalarajkumar1998@gmail.com',
    'retries': 1,
    'retry_delay': timedelta(minutes=2)
}

def retrain_model():
    # Connect to DB
    conn = sqlite3.connect('/opt/airflow/db/predictions.db')
    
    # Load predictions and feedback
    preds_df = pd.read_sql_query("SELECT * FROM predictions", conn)
    fb_df = pd.read_sql_query("SELECT * FROM feedback", conn)

    # Join feedback with predictions
    merged = preds_df.merge(fb_df, left_on='id', right_on='prediction_id')
    
    if merged.empty:
        print("No new feedback to retrain.")
        return

    # Prepare training data
    X = merged[['f1', 'f2']]
    y = merged['correct_label']

    # Retrain model
    clf = RandomForestClassifier()
    clf.fit(X, y)

    # Save model
    model_path = "/opt/airflow/model/model.pkl"
    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    joblib.dump(clf, model_path)

    print(f"Model retrained with {len(X)} samples.")

    conn.close()

# Define DAG
with DAG(
    dag_id='retrain_ai_model',
    default_args=default_args,
    description='Retrain AI model from feedback loop',
    schedule_interval='@daily',  # or '@weekly'
    start_date=datetime(2025, 5, 1),
    catchup=False
) as dag:

    retrain_task = PythonOperator(
        task_id='retrain_model',
        python_callable=retrain_model
    )

    retrain_task