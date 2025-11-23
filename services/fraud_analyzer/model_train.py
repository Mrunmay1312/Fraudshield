# Simple script to train a placeholder model for POC
from sklearn.ensemble import RandomForestClassifier
from sklearn.datasets import make_classification
import joblib
X, y = make_classification(n_samples=5000, n_features=10, weights=[0.97,0.03], random_state=42)
clf = RandomForestClassifier(n_estimators=50, random_state=42)
clf.fit(X,y)
joblib.dump(clf, 'model.joblib')
print('Saved model.joblib')