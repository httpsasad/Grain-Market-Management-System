import os
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
from sklearn.model_selection import train_test_split
import joblib

MODELS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "models_saved")
os.makedirs(MODELS_DIR, exist_ok=True)

def train_price_predictor():
    """
    Trains a Random Forest Regressor to forecast crop rates based on historical seasonal trends.
    Crops: 1: Gandum, 2: Chana, 3: Cotton, 4: Rice, 5: Maize
    """
    np.random.seed(42)
    n_samples = 2000

    crop_ids = np.random.choice([1, 2, 3, 4, 5], size=n_samples)
    months = np.random.randint(1, 13, size=n_samples)
    days_of_year = np.random.randint(1, 365, size=n_samples)
    market_arrivals_tons = np.random.uniform(50, 1500, size=n_samples)

    # Base price per KG by crop
    base_prices = {1: 100.0, 2: 220.0, 3: 280.0, 4: 180.0, 5: 90.0}

    prices = []
    for c_id, m, arr in zip(crop_ids, months, market_arrivals_tons):
        bp = base_prices[c_id]
        # Seasonal multiplier (harvest season drops price slightly, off-season increases)
        seasonal_factor = 1.0 + 0.15 * np.sin(2 * np.pi * m / 12)
        # Arrival volume impact (higher volume = slight price drop)
        volume_factor = 1.0 - (arr / 5000.0)
        noise = np.random.normal(0, 5)
        price = bp * seasonal_factor * volume_factor + noise
        prices.append(round(max(40.0, price), 2))

    df = pd.DataFrame({
        "crop_id": crop_ids,
        "month": months,
        "day_of_year": days_of_year,
        "market_arrivals_tons": market_arrivals_tons,
        "price_per_kg": prices
    })

    X = df[["crop_id", "month", "day_of_year", "market_arrivals_tons"]]
    y = df["price_per_kg"]

    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X, y)

    model_path = os.path.join(MODELS_DIR, "price_predictor.joblib")
    joblib.dump(model, model_path)
    print(f"Price predictor ML model trained and saved to {model_path}")

def train_credit_scorer():
    """
    Trains a Random Forest Classifier to score Farmer Credit Risk:
    Features: total_sales_count, avg_repayment_days, advance_loan_ratio, yield_stability
    Target: 0: Low Risk (Safe), 1: Medium Risk, 2: High Risk (Caution)
    """
    np.random.seed(42)
    n_samples = 1500

    sales_count = np.random.randint(2, 50, size=n_samples)
    repayment_days = np.random.randint(1, 90, size=n_samples)
    advance_ratio = np.random.uniform(0.0, 0.8, size=n_samples) # Loan vs Sale ratio
    yield_stability = np.random.uniform(0.5, 1.0, size=n_samples) # 1.0 = highly stable

    risk_labels = []
    for r_days, adv, y_stab in zip(repayment_days, advance_ratio, yield_stability):
        score = (r_days * 0.4) + (adv * 100 * 0.4) + ((1 - y_stab) * 50 * 0.2)
        if score < 25:
            risk_labels.append(0) # Low Risk
        elif score < 50:
            risk_labels.append(1) # Medium Risk
        else:
            risk_labels.append(2) # High Risk

    df = pd.DataFrame({
        "sales_count": sales_count,
        "repayment_days": repayment_days,
        "advance_ratio": advance_ratio,
        "yield_stability": yield_stability,
        "risk_label": risk_labels
    })

    X = df[["sales_count", "repayment_days", "advance_ratio", "yield_stability"]]
    y = df["risk_label"]

    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X, y)

    model_path = os.path.join(MODELS_DIR, "credit_scorer.joblib")
    joblib.dump(model, model_path)
    print(f"Farmer credit risk ML model trained and saved to {model_path}")

if __name__ == "__main__":
    train_price_predictor()
    train_credit_scorer()
