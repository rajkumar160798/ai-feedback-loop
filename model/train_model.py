import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

# Create mock data
data = {
    "feature1": [0.2, 0.4, 0.6, 0.8, 0.1],
    "feature2": [70, 72, 75, 78, 68],
    "label":    [0, 0, 1, 1, 0]
}

df = pd.DataFrame(data)

# Features and label
X = df[["feature1", "feature2"]]
y = df["label"]

# Train model
clf = RandomForestClassifier()
clf.fit(X, y)

# Save model
os.makedirs("model", exist_ok=True)
joblib.dump(clf, "model/model.pkl")

print("✅ Model trained and saved to model/model.pkl")
