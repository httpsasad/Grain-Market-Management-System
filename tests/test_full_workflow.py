import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from app.db.database import Base
from app.db.models import User, Party, Crop, FasalReceiving, Sale, Settlement, Payment, LedgerEntry
from app.services.auth_service import hash_password
from app.services.settlement_service import process_sale_and_settlement
from app.main import app

TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture
def test_setup():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()

    # Create Test User
    user = User(
        username="mandi_test_user",
        shop_name="Madina Grain Traders",
        owner_name="Chaudhry Asad",
        mobile="03001234567",
        city="Sargodha",
        hashed_password=hash_password("password123")
    )
    session.add(user)
    session.commit()

    # Create Default Crop
    crop = Crop(user_id=user.id, name="Gandum (Wheat)", variety="Super White", unit_default="Mann", current_market_rate=100.0)
    session.add(crop)
    session.commit()

    # Create Parties (Farmer & Buyer & Seller)
    farmer = Party(user_id=user.id, name="Muhammad Tariq (Kisan)", mobile="03011111111", party_type="Farmer", opening_balance=0.0)
    seller = Party(user_id=user.id, name="Malik Riaz (Seller)", mobile="03022222222", party_type="Seller", opening_balance=0.0)
    buyer = Party(user_id=user.id, name="Al-Rehman Flour Mills", mobile="03033333333", party_type="Buyer", opening_balance=0.0)

    session.add_all([farmer, seller, buyer])
    session.commit()

    yield {
        "session": session,
        "user": user,
        "crop": crop,
        "farmer": farmer,
        "seller": seller,
        "buyer": buyer
    }

    session.close()
    Base.metadata.drop_all(bind=engine)

def test_complete_mandi_workflow_receiving_sale_payment(test_setup):
    db = test_setup["session"]
    user = test_setup["user"]
    crop = test_setup["crop"]
    farmer = test_setup["farmer"]
    seller = test_setup["seller"]
    buyer = test_setup["buyer"]

    # 1️⃣ Step 1: Receiving Entry (Farmer Brings 100 Bags / 4,000 KG Wheat)
    rec1 = FasalReceiving(
        user_id=user.id,
        receipt_no="REC-TEST-1001",
        date="2026-10-03",
        farmer_id=farmer.id,
        crop_id=crop.id,
        bags=100,
        gross_weight=4100.0,
        tare_weight=100.0,
        net_weight=4000.0,
        deduction_kg=0.0,
        final_weight=4000.0,
        status="Received"
    )
    db.add(rec1)
    db.commit()
    db.refresh(rec1)
    assert rec1.id is not None
    assert rec1.status == "Received"

    # 2️⃣ Step 2: Receiving Entry 2 (Seller Brings 50 Bags / 2,000 KG Wheat)
    rec2 = FasalReceiving(
        user_id=user.id,
        receipt_no="REC-TEST-1002",
        date="2026-10-03",
        farmer_id=seller.id,
        crop_id=crop.id,
        bags=50,
        gross_weight=2050.0,
        tare_weight=50.0,
        net_weight=2000.0,
        deduction_kg=0.0,
        final_weight=2000.0,
        status="Received"
    )
    db.add(rec2)
    db.commit()

    # 3️⃣ Step 3: Process Sale & Settlement (Bikri of 4,000 KG @ Rs. 100/KG = Rs. 400,000)
    sale1, st1 = process_sale_and_settlement(
        db=db,
        receiving_id=rec1.id,
        buyer_id=buyer.id,
        sale_rate_per_kg=100.0,
        buyer_commission_type="percentage",
        buyer_commission_rate=1.0, # 1% Buyer Comm = Rs. 4,000
        farmer_commission_type="percentage",
        farmer_commission_rate=2.0, # 2% Farmer Comm = Rs. 8,000
        mazdoori_type="per_bag",
        mazdoori_rate=20.0, # 100 bags * 20 = Rs. 2,000
        brokery_type="per_bag",
        brokery_rate=10.0, # 100 bags * 10 = Rs. 1,000
        shop_charges_type="per_bag",
        shop_charges_rate=10.0, # 100 bags * 10 = Rs. 1,000
        approved_expenses=0.0,
        advance_payment_made=50000.0, # Rs. 50,000 Advance Cash Paid
        user_id=user.id
    )

    # Verifications
    assert rec1.status == "Settled"
    assert sale1.total_sale_amount == 400000.0
    assert sale1.buyer_commission_amount == 4000.0
    assert sale1.buyer_total_amount == 404000.0
    assert sale1.farmer_commission_amount == 8000.0
    assert sale1.mazdoori_amount == 2000.0
    assert sale1.brokery_amount == 1000.0
    assert sale1.shop_charges_amount == 1000.0

    # Farmer Net Amount = 400,000 - 8,000 - 2,000 - 1,000 - 1,000 = 388,000
    assert st1.net_farmer_payable == 388000.0
    # Remaining Payable = 388,000 - 50,000 advance = 338,000
    assert st1.remaining_balance == 338000.0

    # 4️⃣ Step 4: Verify Buyer & Farmer Ledgers
    buyer_ledger = db.query(LedgerEntry).filter(LedgerEntry.party_id == buyer.id).all()
    assert len(buyer_ledger) == 1
    assert buyer_ledger[0].debit == 404000.0 # Debited Total Bill

    farmer_ledger = db.query(LedgerEntry).filter(LedgerEntry.party_id == farmer.id).all()
    assert len(farmer_ledger) == 2 # Settlement Credit + Payment Debit
    assert farmer_ledger[0].credit == 388000.0
    assert farmer_ledger[1].debit == 50000.0
    assert farmer_ledger[1].running_balance == -338000.0 # Dena Hai 338,000

    # 5️⃣ Step 5: Payments (Vasooli from Buyer & Final Payment to Farmer)
    # Buyer pays Rs. 404,000
    buyer_pmt = Payment(
        user_id=user.id,
        voucher_no="PAY-BUYER-1",
        date="2026-10-03",
        party_id=buyer.id,
        payment_type="Receipt",
        payment_mode="Cash",
        amount=404000.0
    )
    db.add(buyer_pmt)
    db.commit()
    
    # Farmer paid remaining Rs. 338,000
    farmer_pmt = Payment(
        user_id=user.id,
        voucher_no="PAY-FARMER-1",
        date="2026-10-03",
        party_id=farmer.id,
        payment_type="Payment",
        payment_mode="Cash",
        amount=338000.0
    )
    db.add(farmer_pmt)
    db.commit()

    print("\n✅ COMPLETE MANDI WORKFLOW INTEGRATION TEST PASSED CLEANLY!")
