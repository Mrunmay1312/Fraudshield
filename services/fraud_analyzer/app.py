from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib, os, numpy as np

app = FastAPI(title='Fraud Analyzer POC')

class Transaction(BaseModel):
    transaction_id: str
    amount: float
    card_id: str
    features: dict = {}

MODEL_PATH = os.environ.get('MODEL_PATH', '/app/model.joblib')

@app.on_event('startup')
def load_model():
    global model
    model = None
    if os.path.exists(MODEL_PATH):
        try:
            model = joblib.load(MODEL_PATH)
            print('Model loaded from', MODEL_PATH)
        except Exception as e:
            print('Failed to load model:', e)

@app.post('/infer')
def infer(tx: Transaction):
    if model is None:
        # fallback simple heuristic
        score = min(1.0, tx.amount / 10000.0)
        return {'transaction_id': tx.transaction_id, 'score': score, 'is_fraud': score>0.7, 'explain': 'heuristic'}
    vec = tx.features.get('vector', [tx.amount])
    try:
        proba = model.predict_proba([vec])[0][1] if hasattr(model, 'predict_proba') else float(model.predict([vec])[0])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {'transaction_id': tx.transaction_id, 'score': float(proba), 'is_fraud': proba>0.5, 'explain': 'model'}
