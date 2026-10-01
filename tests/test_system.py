import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from app.db.database import Base
from app.db.models import Party, Crop, FasalReceiving, Sale, Settlement, LedgerEntry, User
from app.services.ledger_service import add_ledger_entry, get_party_ledger, recalculate_party_ledger
from app.services.settlement_service import process_sale_and_settlement, calculate_commission
from app.services.auth_service import create_session_token, decode_token, hash_password, verify_password
from app.ml.price_predictor import predict_crop_price
from app.ml.credit_scorer import evaluate_farmer_risk

TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)

def test_commission_calculation():
    assert calculate_commission(total_sale=250000, quantity_kg=1000, comm_type="percentage", comm_rate=2.0) == 5000.0
    assert calculate_commission(total_sale=250000, quantity_kg=1000, comm_type="per_kg", comm_rate=5.0) == 5000.0
    assert calculate_commission(total_sale=250000, quantity_kg=1000, comm_type="fixed", comm_rate=3000.0) == 3000.0

def test_jwt_auth_tokens():
    token = create_session_token(user_id=42)
    assert token is not None
    decoded = decode_token(token)
    assert decoded == 42

def test_farmer_settlement_and_ledger(db):
    farmer = Party(name="Test Kisan", party_type="Farmer", opening_balance=0.0)
    buyer = Party(name="Test Buyer", party_type="Buyer", opening_balance=0.0)
    crop = Crop(name="Test Wheat", current_market_rate=250.0)

    db.add_all([farmer, buyer, crop])
    db.commit()

    rec = FasalReceiving(
        receipt_no="REC-TEST-1",
        date="2026-09-22",
        farmer_id=farmer.id,
        crop_id=crop.id,
        bags=25,
        gross_weight=1050.0,
        tare_weight=50.0,
        net_weight=1000.0,
        final_weight=1000.0
    )
    db.add(rec)
    db.commit()

    sale, settlement = process_sale_and_settlement(
        db=db,
        receiving_id=rec.id,
        buyer_id=buyer.id,
        sale_rate_per_kg=250.0,
        commission_type="percentage",
        commission_rate=2.0,
        approved_expenses=2000.0,
        advance_payment_made=100000.0
    )

    assert sale.total_sale_amount == 250000.0
    assert sale.commission_amount == 5000.0
    assert settlement.net_farmer_payable == 243000.0
    assert settlement.remaining_balance == 143000.0

    buyer_entries = get_party_ledger(db, buyer.id)
    assert len(buyer_entries) == 1
    assert buyer_entries[0].debit == 250000.0
    assert buyer_entries[0].running_balance == 250000.0

    farmer_entries = get_party_ledger(db, farmer.id)
    assert len(farmer_entries) == 2
    assert farmer_entries[0].credit == 243000.0
    assert farmer_entries[1].debit == 100000.0
    assert farmer_entries[1].running_balance == -143000.0

def test_split_sales(db):
    farmer = Party(name="Split Farmer", party_type="Farmer")
    buyer1 = Party(name="Buyer 1", party_type="Buyer")
    buyer2 = Party(name="Buyer 2", party_type="Buyer")
    crop = Crop(name="Gandum")
    db.add_all([farmer, buyer1, buyer2, crop])
    db.commit()

    rec = FasalReceiving(
        receipt_no="REC-SPLIT",
        date="2026-10-01",
        farmer_id=farmer.id,
        crop_id=crop.id,
        gross_weight=1000.0,
        net_weight=1000.0,
        final_weight=1000.0,
        status="Received"
    )
    db.add(rec)
    db.commit()

    # Sale 1: Sell 400 KG to Buyer 1
    sale1, st1 = process_sale_and_settlement(
        db=db,
        receiving_id=rec.id,
        buyer_id=buyer1.id,
        sale_rate_per_kg=100.0,
        commission_type="percentage",
        commission_rate=2.0,
        approved_expenses=0.0,
        advance_payment_made=0.0,
        sale_quantity_kg=400.0
    )
    assert sale1.quantity_kg == 400.0
    assert rec.status == "Partially Sold"

    # Sale 2: Sell remaining 600 KG to Buyer 2
    sale2, st2 = process_sale_and_settlement(
        db=db,
        receiving_id=rec.id,
        buyer_id=buyer2.id,
        sale_rate_per_kg=105.0,
        commission_type="percentage",
        commission_rate=2.0,
        approved_expenses=0.0,
        advance_payment_made=0.0,
        sale_quantity_kg=600.0
    )
    assert sale2.quantity_kg == 600.0
    assert rec.status == "Settled"

def test_ml_models():
    pred = predict_crop_price(crop_id=1, days_ahead=7)
    assert "predicted_rate_kg" in pred
    assert pred["predicted_rate_kg"] > 0

    risk = evaluate_farmer_risk(sales_count=10, repayment_days=10, advance_ratio=0.1)
    assert "risk_label" in risk
    assert "score" in risk

def test_farmer_initial_payment_and_khata(db):
    farmer = Party(name="New Farmer", party_type="Farmer", opening_balance=0.0)
    db.add(farmer)
    db.commit()

    entry1 = add_ledger_entry(
        db=db,
        party_id=farmer.id,
        date_str="2026-09-22",
        description="Initial Payment Given (Diye)",
        debit=50000.0,
        credit=0.0,
        reference_type="Payment"
    )
    assert entry1.debit == 50000.0
    assert entry1.running_balance == 50000.0

    entry2 = add_ledger_entry(
        db=db,
        party_id=farmer.id,
        date_str="2026-09-22",
        description="Payment Received (Liye)",
        debit=0.0,
        credit=15000.0,
        reference_type="Payment"
    )
    assert entry2.credit == 15000.0
    assert entry2.running_balance == 35000.0

def test_multi_tenant_isolation(db):
    user1 = User(username="shop_alpha", shop_name="Alpha Traders", owner_name="Alpha Owner", mobile="03001111111", city="Lahore", hashed_password=hash_password("pass123"))
    user2 = User(username="shop_beta", shop_name="Beta Traders", owner_name="Beta Owner", mobile="03002222222", city="Multan", hashed_password=hash_password("pass123"))
    db.add_all([user1, user2])
    db.commit()

    assert verify_password("pass123", user1.hashed_password) is True

    farmer1 = Party(user_id=user1.id, name="Kisan Alpha", party_type="Farmer")
    db.add(farmer1)
    db.commit()

    farmer2 = Party(user_id=user2.id, name="Kisan Beta", party_type="Farmer")
    db.add(farmer2)
    db.commit()

    user1_farmers = db.query(Party).filter(Party.user_id == user1.id).all()
    user2_farmers = db.query(Party).filter(Party.user_id == user2.id).all()

    assert len(user1_farmers) == 1
    assert user1_farmers[0].name == "Kisan Alpha"

    assert len(user2_farmers) == 1
    assert user2_farmers[0].name == "Kisan Beta"
