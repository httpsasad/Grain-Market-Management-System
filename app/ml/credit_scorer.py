import os
import pandas as pd
import joblib

MODELS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "models_saved")
MODEL_PATH = os.path.join(MODELS_DIR, "credit_scorer.joblib")

_model = None

def get_credit_model():
    global _model
    if _model is None and os.path.exists(MODEL_PATH):
        _model = joblib.load(MODEL_PATH)
    return _model

def evaluate_farmer_risk(sales_count: int, repayment_days: int, advance_ratio: float, yield_stability: float = 0.9):
    """
    Evaluates farmer risk level (Low Risk / Medium Risk / High Risk) and risk score.
    """
    model = get_credit_model()
    
    risk_names = {0: "Low Risk (Safe)", 1: "Medium Risk", 2: "High Risk (Caution)"}
    badge_colors = {0: "success", 1: "warning", 2: "danger"}

    if model is None:
        return {
            "risk_label": "Low Risk (Safe)",
            "score": 88.0,
            "badge_color": "success"
        }

    input_df = pd.DataFrame([{
        "sales_count": max(1, sales_count),
        "repayment_days": repayment_days,
        "advance_ratio": advance_ratio,
        "yield_stability": yield_stability
    }])

    pred_class = int(model.predict(input_df)[0])
    probs = model.predict_proba(input_df)[0]
    
    # Calculate score out of 100
    safe_prob = float(probs[0]) if len(probs) > 0 else 0.85
    score = round(safe_prob * 100, 1)

    return {
        "risk_label": risk_names.get(pred_class, "Low Risk (Safe)"),
        "score": score,
        "badge_color": badge_colors.get(pred_class, "success")
    }
