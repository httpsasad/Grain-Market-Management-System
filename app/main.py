import os
import datetime
from typing import Optional, List
from fastapi import FastAPI, Depends, Request, Form, HTTPException, Query, status
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.database import get_db, engine, Base
from app.db.models import User, Party, Crop, FasalReceiving, Sale, Settlement, Payment, Expense, LedgerEntry
from app.db.seed import seed_initial_data
from app.services.auth_service import (
    hash_password,
    verify_password,
    create_session_token,
    get_current_user_optional,
    get_current_user
)
from app.services.ledger_service import add_ledger_entry, get_party_ledger, recalculate_party_ledger
from app.services.settlement_service import process_sale_and_settlement
from app.ml.price_predictor import predict_crop_price
from app.ml.credit_scorer import evaluate_farmer_risk
from app.schemas import (
    LoginRequest, SignupRequest, TokenResponse, UserProfileResponse,
    PartyCreate, PartyUpdate, ReceivingCreate, ReceivingUpdate, SaleProcessRequest, PaymentCreate, ManualLedgerEntryCreate
)

from fastapi.middleware.cors import CORSMiddleware

# Create Database tables & seed initial data
Base.metadata.create_all(bind=engine)
seed_initial_data()

app = FastAPI(
    title="Grain Market Management System (Mandi ERP & REST API)",
    version="2.0.0",
    description="AI Mandi ERP with Multi-Tenancy, Double-Entry Ledger & Mobile App REST APIs"
)

# Enable CORS for external mobile data & tunnel connections
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Static Files & Templates
BASE_DIR = os.path.dirname(__file__)
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

# ==================== MOBILE & WEB AUTHENTICATION API (REST) ====================

@app.post("/api/v1/auth/login", response_model=TokenResponse)
def api_login(payload: LoginRequest, db: Session = Depends(get_db)):
    login_val = payload.username.strip()
    user = db.query(User).filter(
        (User.username == login_val) | (User.mobile == login_val)
    ).first()
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Ghalat Username/Mobile ya Password! Baraye meharbani dobara koshish karein."
        )

    token = create_session_token(user.id)
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        username=user.username,
        shop_name=user.shop_name,
        owner_name=user.owner_name
    )

@app.post("/api/v1/auth/signup", response_model=TokenResponse)
def api_signup(payload: SignupRequest, db: Session = Depends(get_db)):
    username_clean = payload.username.strip()
    existing = db.query(User).filter(User.username == username_clean).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Yeh Username pehle se zair-e-istemal hai."
        )

    new_user = User(
        username=username_clean,
        shop_name=payload.shop_name.strip(),
        owner_name=payload.owner_name.strip(),
        mobile=payload.mobile.strip(),
        city=payload.city.strip(),
        hashed_password=hash_password(payload.password)
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    default_crops = [
        Crop(user_id=new_user.id, name="Gandum (Wheat)", variety="Super White", unit_default="Mann", current_market_rate=105.0),
        Crop(user_id=new_user.id, name="Chana (Chickpeas)", variety="Desi Grade A", unit_default="Mann", current_market_rate=225.0),
        Crop(user_id=new_user.id, name="Cotton (Kapas)", variety="Phutti Grade A", unit_default="Mann", current_market_rate=290.0),
        Crop(user_id=new_user.id, name="Rice (Basmati)", variety="Super Kernel", unit_default="Mann", current_market_rate=185.0),
        Crop(user_id=new_user.id, name="Maize (Makai)", variety="Hybrid Yellow", unit_default="Mann", current_market_rate=95.0),
    ]
    db.add_all(default_crops)
    db.commit()

    token = create_session_token(new_user.id)
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=new_user.id,
        username=new_user.username,
        shop_name=new_user.shop_name,
        owner_name=new_user.owner_name
    )

@app.get("/api/v1/auth/me", response_model=UserProfileResponse)
def api_get_me(current_user: User = Depends(get_current_user)):
    return UserProfileResponse(
        id=current_user.id,
        username=current_user.username,
        shop_name=current_user.shop_name,
        owner_name=current_user.owner_name,
        mobile=current_user.mobile,
        city=current_user.city
    )

# ==================== MOBILE & REST DASHBOARD API ====================

@app.get("/api/v1/dashboard/stats")
def api_dashboard_stats(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    today_str = datetime.date.today().strftime("%Y-%m-%d")

    today_sales = (
        db.query(func.sum(Sale.total_sale_amount))
        .filter(Sale.user_id == current_user.id, Sale.date == today_str)
        .scalar() or 0.0
    )
    today_commission = (
        db.query(func.sum(Sale.commission_amount))
        .filter(Sale.user_id == current_user.id, Sale.date == today_str)
        .scalar() or 0.0
    )
    today_receivings_count = (
        db.query(FasalReceiving)
        .filter(FasalReceiving.user_id == current_user.id, FasalReceiving.date == today_str)
        .count()
    )

    parties = db.query(Party).filter(Party.user_id == current_user.id).all()
    total_receivable = 0.0
    total_payable = 0.0
    for p in parties:
        last_entry = (
            db.query(LedgerEntry)
            .filter(LedgerEntry.party_id == p.id, LedgerEntry.user_id == current_user.id)
            .order_by(LedgerEntry.id.desc())
            .first()
        )
        bal = last_entry.running_balance if last_entry else (p.opening_balance if p.balance_type == "Receivable" else -p.opening_balance)
        if bal > 0:
            total_receivable += bal
        else:
            total_payable += abs(bal)

    pending_receivings = (
        db.query(FasalReceiving)
        .filter(FasalReceiving.user_id == current_user.id, FasalReceiving.status.in_(["Received", "Partially Sold"]))
        .count()
    )

    return {
        "status": "success",
        "today_sales": today_sales,
        "today_commission": today_commission,
        "today_receivings_count": today_receivings_count,
        "total_receivable": total_receivable,
        "total_payable": total_payable,
        "pending_receivings_count": pending_receivings
    }

# ==================== MOBILE & REST PARTIES API ====================

@app.get("/api/v1/parties")
def api_get_parties(
    party_type: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    query = db.query(Party).filter(Party.user_id == current_user.id)
    if party_type and party_type != "All":
        query = query.filter(Party.party_type == party_type)
    parties = query.order_by(Party.id.desc()).all()

    res = []
    for p in parties:
        last_entry = (
            db.query(LedgerEntry)
            .filter(LedgerEntry.party_id == p.id, LedgerEntry.user_id == current_user.id)
            .order_by(LedgerEntry.id.desc())
            .first()
        )
        bal = last_entry.running_balance if last_entry else (p.opening_balance if p.balance_type == "Receivable" else -p.opening_balance)
        res.append({
            "id": p.id,
            "name": p.name,
            "mobile": p.mobile,
            "cnic": p.cnic,
            "address": p.address,
            "party_type": p.party_type,
            "balance": abs(bal),
            "balance_status": "Receivable (Lena Hai)" if bal >= 0 else "Payable (Dena Hai)",
            "credit_risk_score": p.credit_risk_score,
            "risk_level": p.risk_level
        })
    return {"status": "success", "data": res}

@app.post("/api/v1/parties")
def api_create_party(
    payload: PartyCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    risk_info = evaluate_farmer_risk(sales_count=1, repayment_days=15, advance_ratio=0.1)

    party = Party(
        user_id=current_user.id,
        name=payload.name.strip(),
        mobile=payload.mobile.strip() if payload.mobile else "",
        cnic=payload.cnic.strip() if payload.cnic else "",
        address=payload.address.strip() if payload.address else "",
        party_type=payload.party_type,
        opening_balance=payload.opening_balance,
        balance_type=payload.balance_type,
        credit_risk_score=risk_info["score"],
        risk_level=risk_info["risk_label"]
    )
    db.add(party)
    db.commit()
    db.refresh(party)

    today_str = datetime.date.today().strftime("%Y-%m-%d")

    if payload.opening_balance > 0:
        debit = payload.opening_balance if payload.balance_type == "Receivable" else 0.0
        credit = payload.opening_balance if payload.balance_type == "Payable" else 0.0
        add_ledger_entry(
            db=db,
            party_id=party.id,
            date_str=today_str,
            description=f"Opening Balance ({payload.balance_type})",
            debit=debit,
            credit=credit,
            reference_type="Opening",
            user_id=current_user.id
        )

    if payload.initial_payment_amount > 0:
        voucher_no = f"PAY-{int(datetime.datetime.now().timestamp())}"
        pmt_notes = payload.initial_payment_notes or ("Initial Payment Given (Diye)" if payload.initial_payment_type == "Payment" else "Initial Payment Received (Vasooli/Liye)")
        payment = Payment(
            user_id=current_user.id,
            voucher_no=voucher_no,
            date=today_str,
            party_id=party.id,
            payment_type=payload.initial_payment_type,
            payment_mode=payload.initial_payment_mode,
            amount=payload.initial_payment_amount,
            reference_no="",
            notes=pmt_notes
        )
        db.add(payment)
        db.commit()

        debit = payload.initial_payment_amount if payload.initial_payment_type == "Payment" else 0.0
        credit = 0.0 if payload.initial_payment_type == "Payment" else payload.initial_payment_amount
        desc = f"Cash Payment Given (Diye)" if payload.initial_payment_type == "Payment" else "Cash Payment Received (Vasooli/Liye)"

        add_ledger_entry(
            db=db,
            party_id=party.id,
            date_str=today_str,
            description=f"{desc} [{payload.initial_payment_mode}] - {pmt_notes}",
            debit=debit,
            credit=credit,
            reference_type="Payment",
            reference_id=payment.id,
            user_id=current_user.id
        )

    return {"status": "success", "message": "Party successfully created!", "party_id": party.id}

@app.put("/api/v1/parties/{party_id}")
def api_update_party(
    party_id: int,
    payload: PartyUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    party = db.query(Party).filter(Party.id == party_id, Party.user_id == current_user.id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Party not found")

    party.name = payload.name.strip()
    party.mobile = payload.mobile.strip() if payload.mobile else ""
    party.cnic = payload.cnic.strip() if payload.cnic else ""
    party.address = payload.address.strip() if payload.address else ""
    party.party_type = payload.party_type
    party.opening_balance = payload.opening_balance
    party.balance_type = payload.balance_type

    opening_entry = db.query(LedgerEntry).filter(
        LedgerEntry.party_id == party_id,
        LedgerEntry.reference_type == "Opening",
        LedgerEntry.user_id == current_user.id
    ).first()

    if opening_entry:
        opening_entry.debit = payload.opening_balance if payload.balance_type == "Receivable" else 0.0
        opening_entry.credit = payload.opening_balance if payload.balance_type == "Payable" else 0.0
        opening_entry.description = f"Opening Balance ({payload.balance_type})"

    db.commit()
    recalculate_party_ledger(db, party_id=party_id, user_id=current_user.id)

    return {"status": "success", "message": "Party updated successfully"}

@app.delete("/api/v1/parties/{party_id}")
def api_delete_party(party_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    party = db.query(Party).filter(Party.id == party_id, Party.user_id == current_user.id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Party not found")

    db.query(LedgerEntry).filter(LedgerEntry.party_id == party_id, LedgerEntry.user_id == current_user.id).delete(synchronize_session=False)
    db.query(Payment).filter(Payment.party_id == party_id, Payment.user_id == current_user.id).delete(synchronize_session=False)
    db.query(Settlement).filter(Settlement.farmer_id == party_id, Settlement.user_id == current_user.id).delete(synchronize_session=False)
    db.query(Sale).filter(Sale.buyer_id == party_id, Sale.user_id == current_user.id).delete(synchronize_session=False)
    db.query(FasalReceiving).filter(FasalReceiving.farmer_id == party_id, FasalReceiving.user_id == current_user.id).delete(synchronize_session=False)
    db.delete(party)
    db.commit()

    return {"status": "success", "message": "Party and related records deleted"}

# ==================== MOBILE & REST RECEIVINGS & SALES API ====================

# ==================== MOBILE & REST CROPS API ====================

@app.get("/api/v1/crops")
def api_get_crops(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    crops = db.query(Crop).filter(Crop.user_id == current_user.id).all()
    if not crops:
        default_crops = [
            Crop(user_id=current_user.id, name="Gandum (Wheat)", variety="Super White", unit_default="Mann", current_market_rate=105.0),
            Crop(user_id=current_user.id, name="Chana (Chickpeas)", variety="Desi Grade A", unit_default="Mann", current_market_rate=225.0),
            Crop(user_id=current_user.id, name="Cotton (Kapas)", variety="Phutti Grade A", unit_default="Mann", current_market_rate=290.0),
            Crop(user_id=current_user.id, name="Rice (Basmati)", variety="Super Kernel", unit_default="Mann", current_market_rate=185.0),
            Crop(user_id=current_user.id, name="Maize (Makai)", variety="Hybrid Yellow", unit_default="Mann", current_market_rate=95.0),
        ]
        db.add_all(default_crops)
        db.commit()
        crops = db.query(Crop).filter(Crop.user_id == current_user.id).all()

    res = []
    for c in crops:
        res.append({
            "id": c.id,
            "name": c.name,
            "variety": c.variety,
            "unit_default": c.unit_default,
            "current_market_rate": c.current_market_rate
        })
    return {"status": "success", "data": res}

# ==================== MOBILE & REST RECEIVINGS & SALES API ====================

@app.get("/api/v1/receivings")
def api_get_receivings(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    receivings = (
        db.query(FasalReceiving)
        .filter(FasalReceiving.user_id == current_user.id)
        .order_by(FasalReceiving.id.desc())
        .all()
    )
    data = []
    for r in receivings:
        data.append({
            "id": r.id,
            "receipt_no": r.receipt_no,
            "date": r.date,
            "farmer_name": r.farmer.name if r.farmer else "Unknown",
            "crop_name": r.crop.name if r.crop else "Unknown",
            "bags": r.bags,
            "gross_weight": r.gross_weight,
            "tare_weight": r.tare_weight,
            "net_weight": r.net_weight,
            "deduction_kg": r.deduction_kg,
            "final_weight": r.final_weight,
            "status": r.status
        })
    return {"status": "success", "data": data}

@app.post("/api/v1/receivings")
def api_create_receiving(payload: ReceivingCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    farmer = db.query(Party).filter(Party.id == payload.farmer_id, Party.user_id == current_user.id).first()
    if not farmer:
        raise HTTPException(status_code=400, detail="Muntakhib karda Farmer system mein nahi mila.")

    crop = db.query(Crop).filter((Crop.id == payload.crop_id) & ((Crop.user_id == current_user.id) | (Crop.user_id == None))).first()
    if not crop:
        raise HTTPException(status_code=400, detail="Muntakhib karda Crop (Jins) system mein nahi mila.")

    net_weight = max(0.0, payload.gross_weight - payload.tare_weight)
    final_weight = max(0.0, net_weight - payload.deduction_kg)
    date_str = datetime.date.today().strftime("%Y-%m-%d")
    receipt_no = f"REC-{int(datetime.datetime.now().timestamp() * 1000)}"

    rec = FasalReceiving(
        user_id=current_user.id,
        receipt_no=receipt_no,
        date=date_str,
        farmer_id=payload.farmer_id,
        crop_id=payload.crop_id,
        bags=payload.bags,
        gross_weight=payload.gross_weight,
        tare_weight=payload.tare_weight,
        net_weight=net_weight,
        moisture_percent=payload.moisture_percent,
        deduction_kg=payload.deduction_kg,
        final_weight=final_weight,
        bardana_charge=payload.bardana_charge,
        transport_charge=payload.transport_charge,
        status="Received"
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)

    return {"status": "success", "message": "Fasal Receiving added!", "receiving_id": rec.id, "receipt_no": receipt_no}

@app.put("/api/v1/receivings/{receiving_id}")
def api_update_receiving(
    receiving_id: int,
    payload: ReceivingUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    rec = db.query(FasalReceiving).filter(FasalReceiving.id == receiving_id, FasalReceiving.user_id == current_user.id).first()
    if not rec:
        raise HTTPException(status_code=404, detail="Fasal Receiving record nahi mila.")

    farmer = db.query(Party).filter(Party.id == payload.farmer_id, Party.user_id == current_user.id).first()
    if not farmer:
        raise HTTPException(status_code=400, detail="Muntakhib karda Farmer system mein nahi mila.")

    crop = db.query(Crop).filter((Crop.id == payload.crop_id) & ((Crop.user_id == current_user.id) | (Crop.user_id == None))).first()
    if not crop:
        raise HTTPException(status_code=400, detail="Muntakhib karda Crop (Jins) system mein nahi mila.")

    net_weight = max(0.0, payload.gross_weight - payload.tare_weight)
    final_weight = max(0.0, net_weight - payload.deduction_kg)

    rec.farmer_id = payload.farmer_id
    rec.crop_id = payload.crop_id
    rec.bags = payload.bags
    rec.gross_weight = payload.gross_weight
    rec.tare_weight = payload.tare_weight
    rec.net_weight = net_weight
    rec.moisture_percent = payload.moisture_percent
    rec.deduction_kg = payload.deduction_kg
    rec.final_weight = final_weight
    rec.bardana_charge = payload.bardana_charge
    rec.transport_charge = payload.transport_charge

    db.commit()
    db.refresh(rec)
    return {"status": "success", "message": "Fasal Receiving entry updated successfully"}

@app.delete("/api/v1/receivings/{receiving_id}")
def api_delete_receiving(
    receiving_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    rec = db.query(FasalReceiving).filter(FasalReceiving.id == receiving_id, FasalReceiving.user_id == current_user.id).first()
    if not rec:
        raise HTTPException(status_code=404, detail="Fasal Receiving record nahi mila.")

    sales_count = db.query(Sale).filter(Sale.receiving_id == receiving_id).count()
    if sales_count > 0:
        raise HTTPException(status_code=400, detail="Yeh Aamad bechi (Sale) ja chuki hai. Pehle iski Sale/Settlement delete karein.")

    db.delete(rec)
    db.commit()
    return {"status": "success", "message": "Fasal Receiving record deleted"}

@app.post("/api/v1/sales/process")
def api_process_sale(payload: SaleProcessRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    buyer = db.query(Party).filter(Party.id == payload.buyer_id, Party.user_id == current_user.id).first()
    if not buyer:
        raise HTTPException(status_code=400, detail="Muntakhib karda Buyer (خریدار) system mein nahi mila.")

    try:
        sale, settlement = process_sale_and_settlement(
            db=db,
            receiving_id=payload.receiving_id,
            buyer_id=payload.buyer_id,
            sale_rate_per_kg=payload.sale_rate_per_kg,
            commission_type=payload.commission_type,
            commission_rate=payload.commission_rate,
            approved_expenses=payload.approved_expenses,
            advance_payment_made=payload.advance_payment_made,
            notes=payload.notes or "",
            sale_quantity_kg=payload.sale_quantity_kg,
            user_id=current_user.id,
            mazdoori_type=payload.mazdoori_type,
            mazdoori_rate=payload.mazdoori_rate,
            buyer_commission_type=payload.buyer_commission_type,
            buyer_commission_rate=payload.buyer_commission_rate,
            farmer_commission_type=payload.farmer_commission_type,
            farmer_commission_rate=payload.farmer_commission_rate
        )
        return {
            "status": "success",
            "message": "Sale and settlement processed successfully",
            "sale_id": sale.id,
            "sale_no": sale.sale_no,
            "settlement_id": settlement.id,
            "settlement_no": settlement.settlement_no,
            "total_sale_amount": sale.total_sale_amount,
            "buyer_commission_amount": sale.buyer_commission_amount,
            "buyer_total_amount": sale.buyer_total_amount,
            "farmer_commission_amount": sale.farmer_commission_amount,
            "mazdoori_amount": sale.mazdoori_amount,
            "net_farmer_payable": settlement.net_farmer_payable
        }
            "commission_amount": sale.commission_amount,
            "mazdoori_amount": sale.mazdoori_amount,
            "net_farmer_payable": settlement.net_farmer_payable
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/v1/ledger/{party_id}")
def api_get_ledger(party_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    entries = get_party_ledger(db, party_id=party_id, user_id=current_user.id)
    party = db.query(Party).filter(Party.id == party_id, Party.user_id == current_user.id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Party not found")

    res = []
    for e in entries:
        res.append({
            "id": e.id,
            "date": e.date,
            "description": e.description,
            "debit": e.debit,
            "credit": e.credit,
            "running_balance": e.running_balance,
            "reference_type": e.reference_type,
            "reference_id": e.reference_id
        })
    return {"status": "success", "party_name": party.name, "party_type": party.party_type, "ledger": res}

@app.post("/api/v1/ledger/entry")
def api_add_ledger_entry(
    payload: ManualLedgerEntryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    party = db.query(Party).filter(Party.id == payload.party_id, Party.user_id == current_user.id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Party not found")

    date_str = payload.date if (payload.date and payload.date.strip()) else datetime.date.today().strftime("%Y-%m-%d")
    debit = payload.amount if payload.entry_type == "Debit" else 0.0
    credit = payload.amount if payload.entry_type == "Credit" else 0.0

    entry = add_ledger_entry(
        db=db,
        party_id=payload.party_id,
        date_str=date_str,
        description=payload.description.strip(),
        debit=debit,
        credit=credit,
        reference_type="Manual",
        user_id=current_user.id
    )

    return {
        "status": "success",
        "message": "Ledger entry added successfully",
        "entry_id": entry.id,
        "running_balance": entry.running_balance
    }

@app.get("/api/v1/payments")
def api_get_payments(
    party_id: Optional[int] = None,
    payment_type: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    query = db.query(Payment).filter(Payment.user_id == current_user.id)
    if party_id:
        query = query.filter(Payment.party_id == party_id)
    if payment_type and payment_type != "All":
        query = query.filter(Payment.payment_type == payment_type)

    payments = query.order_by(Payment.id.desc()).all()
    res = []
    for p in payments:
        res.append({
            "id": p.id,
            "voucher_no": p.voucher_no,
            "date": p.date,
            "party_name": p.party.name if p.party else "Unknown",
            "payment_type": p.payment_type,
            "payment_mode": p.payment_mode,
            "amount": p.amount,
            "notes": p.notes
        })
    return {"status": "success", "data": res}

@app.post("/api/v1/payments")
def api_add_payment(payload: PaymentCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    party = db.query(Party).filter(Party.id == payload.party_id, Party.user_id == current_user.id).first()
    if not party:
        raise HTTPException(status_code=400, detail="Muntakhib karda Party (کھاتہ دار) system mein nahi mila.")

    if payload.amount <= 0:
        raise HTTPException(status_code=400, detail="Baraye meharbani payment ki rakam 0 se zyada enter karein.")

    date_str = datetime.date.today().strftime("%Y-%m-%d")
    voucher_no = f"PAY-{int(datetime.datetime.now().timestamp() * 1000)}"

    payment = Payment(
        user_id=current_user.id,
        voucher_no=voucher_no,
        date=date_str,
        party_id=payload.party_id,
        payment_type=payload.payment_type,
        payment_mode=payload.payment_mode,
        amount=payload.amount,
        reference_no=payload.reference_no or "",
        notes=payload.notes or ""
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)

    if payload.payment_type == "Payment":
        debit = payload.amount
        credit = 0.0
        desc = f"Cash Payment Given (Diye) [{payload.payment_mode}] - {payload.notes or 'Direct Payment'}"
    else:
        debit = 0.0
        credit = payload.amount
        desc = f"Cash Payment Received (Vasooli/Liye) [{payload.payment_mode}] - {payload.notes or 'Direct Receipt'}"

    add_ledger_entry(
        db=db,
        party_id=payload.party_id,
        date_str=date_str,
        description=desc,
        debit=debit,
        credit=credit,
        reference_type="Payment",
        reference_id=payment.id,
        user_id=current_user.id
    )

    return {"status": "success", "message": "Payment recorded", "voucher_no": voucher_no}


# ==================== WEB AUTHENTICATION ROUTES (HTML) ====================

@app.get("/login", response_class=HTMLResponse)
def login_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if user:
        return RedirectResponse(url="/", status_code=303)
    return templates.TemplateResponse(request=request, name="login.html")

@app.post("/login")
def login_submit(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    login_val = username.strip()
    user = db.query(User).filter(
        (User.username == login_val) | (User.mobile == login_val)
    ).first()
    if not user or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse(
            request=request,
            name="login.html",
            context={"error": "Ghalat Username/Mobile ya Password! Baraye meharbani dobara koshish karein."}
        )

    token = create_session_token(user.id)
    response = RedirectResponse(url="/", status_code=303)
    response.set_cookie(key="session_token", value=token, httponly=True, max_age=86400 * 30)
    return response

@app.get("/signup", response_class=HTMLResponse)
def signup_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if user:
        return RedirectResponse(url="/", status_code=303)
    return templates.TemplateResponse(request=request, name="signup.html")

@app.post("/signup")
def signup_submit(
    request: Request,
    username: str = Form(...),
    shop_name: str = Form(...),
    owner_name: str = Form(...),
    mobile: str = Form(...),
    city: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    username_clean = username.strip()
    existing = db.query(User).filter(User.username == username_clean).first()
    if existing:
        return templates.TemplateResponse(
            request=request,
            name="signup.html",
            context={"error": "Yeh Username pehle se zair-e-istemal hai. Baraye meharbani koi doosra username ya mobile chunein."}
        )

    new_user = User(
        username=username_clean,
        shop_name=shop_name.strip(),
        owner_name=owner_name.strip(),
        mobile=mobile.strip(),
        city=city.strip(),
        hashed_password=hash_password(password)
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    default_crops = [
        Crop(user_id=new_user.id, name="Gandum (Wheat)", variety="Super White", unit_default="Mann", current_market_rate=105.0),
        Crop(user_id=new_user.id, name="Chana (Chickpeas)", variety="Desi Grade A", unit_default="Mann", current_market_rate=225.0),
        Crop(user_id=new_user.id, name="Cotton (Kapas)", variety="Phutti Grade A", unit_default="Mann", current_market_rate=290.0),
        Crop(user_id=new_user.id, name="Rice (Basmati)", variety="Super Kernel", unit_default="Mann", current_market_rate=185.0),
        Crop(user_id=new_user.id, name="Maize (Makai)", variety="Hybrid Yellow", unit_default="Mann", current_market_rate=95.0),
    ]
    db.add_all(default_crops)
    db.commit()

    token = create_session_token(new_user.id)
    response = RedirectResponse(url="/", status_code=303)
    response.set_cookie(key="session_token", value=token, httponly=True, max_age=86400 * 30)
    return response

@app.get("/logout")
def logout():
    response = RedirectResponse(url="/login", status_code=303)
    response.delete_cookie("session_token")
    return response

@app.get("/profile", response_class=HTMLResponse)
def profile_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    return templates.TemplateResponse(
        request=request,
        name="profile.html",
        context={"current_user": user, "active_tab": "profile"}
    )

@app.post("/profile/update")
def profile_update(
    request: Request,
    shop_name: str = Form(...),
    owner_name: str = Form(...),
    mobile: str = Form(...),
    city: str = Form(...),
    new_password: str = Form(""),
    db: Session = Depends(get_db)
):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    user.shop_name = shop_name.strip()
    user.owner_name = owner_name.strip()
    user.mobile = mobile.strip()
    user.city = city.strip()
    if new_password.strip():
        user.hashed_password = hash_password(new_password.strip())

    db.commit()
    db.refresh(user)

    return templates.TemplateResponse(
        request=request,
        name="profile.html",
        context={
            "current_user": user,
            "message": "Dukan settings successfully update ho gayin!",
            "active_tab": "profile"
        }
    )

# ==================== MAIN CORE WEB APP ROUTES ====================

@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    today_str = datetime.date.today().strftime("%Y-%m-%d")

    today_sales = (
        db.query(func.sum(Sale.total_sale_amount))
        .filter(Sale.user_id == user.id, Sale.date == today_str)
        .scalar() or 0.0
    )
    today_commission = (
        db.query(func.sum(Sale.commission_amount))
        .filter(Sale.user_id == user.id, Sale.date == today_str)
        .scalar() or 0.0
    )
    today_receivings_count = (
        db.query(FasalReceiving)
        .filter(FasalReceiving.user_id == user.id, FasalReceiving.date == today_str)
        .count()
    )

    parties = db.query(Party).filter(Party.user_id == user.id).all()
    total_receivable = 0.0
    total_payable = 0.0
    for p in parties:
        last_entry = (
            db.query(LedgerEntry)
            .filter(LedgerEntry.party_id == p.id, LedgerEntry.user_id == user.id)
            .order_by(LedgerEntry.id.desc())
            .first()
        )
        bal = last_entry.running_balance if last_entry else (p.opening_balance if p.balance_type == "Receivable" else -p.opening_balance)
        if bal > 0:
            total_receivable += bal
        else:
            total_payable += abs(bal)

    crops = db.query(Crop).filter(Crop.user_id == user.id).all()
    if not crops:
        crops = db.query(Crop).filter(Crop.user_id == None).all()

    ml_predictions = []
    for crop in crops:
        pred = predict_crop_price(crop_id=crop.id, days_ahead=7)
        ml_predictions.append({
            "crop": crop,
            "pred_rate_kg": pred["predicted_rate_kg"],
            "pred_rate_mann": pred["predicted_rate_mann"],
            "confidence": pred["confidence"]
        })

    recent_sales = (
        db.query(Sale)
        .filter(Sale.user_id == user.id)
        .order_by(Sale.id.desc())
        .limit(5)
        .all()
    )
    pending_receivings = (
        db.query(FasalReceiving)
        .filter(FasalReceiving.user_id == user.id, FasalReceiving.status.in_(["Received", "Partially Sold"]))
        .all()
    )

    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "current_user": user,
            "today_sales": today_sales,
            "today_commission": today_commission,
            "today_receivings_count": today_receivings_count,
            "total_receivable": total_receivable,
            "total_payable": total_payable,
            "ml_predictions": ml_predictions,
            "recent_sales": recent_sales,
            "pending_receivings_count": len(pending_receivings),
            "active_tab": "dashboard"
        }
    )

@app.get("/parties", response_class=HTMLResponse)
def parties_page(request: Request, party_type: Optional[str] = None, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    query = db.query(Party).filter(Party.user_id == user.id)
    if party_type and party_type != "All":
        query = query.filter(Party.party_type == party_type)
    parties = query.order_by(Party.id.desc()).all()
    all_parties = db.query(Party).filter(Party.user_id == user.id).order_by(Party.name.asc()).all()

    party_list = []
    for p in parties:
        last_entry = (
            db.query(LedgerEntry)
            .filter(LedgerEntry.party_id == p.id, LedgerEntry.user_id == user.id)
            .order_by(LedgerEntry.id.desc())
            .first()
        )
        bal = last_entry.running_balance if last_entry else (p.opening_balance if p.balance_type == "Receivable" else -p.opening_balance)
        party_list.append({
            "party": p,
            "current_balance": abs(bal),
            "balance_status": "Receivable (Lena Hai)" if bal >= 0 else "Payable (Dena Hai)"
        })

    return templates.TemplateResponse(
        request=request,
        name="parties.html",
        context={
            "current_user": user,
            "party_list": party_list,
            "all_parties": all_parties,
            "selected_type": party_type or "All",
            "active_tab": "parties"
        }
    )

@app.post("/parties/add")
def add_party(
    request: Request,
    name: str = Form(...),
    mobile: str = Form(...),
    cnic: str = Form(""),
    address: str = Form(""),
    party_type: str = Form(...),
    opening_balance: float = Form(0.0),
    balance_type: str = Form("Receivable"),
    initial_payment_amount: float = Form(0.0),
    initial_payment_type: str = Form("Payment"),
    initial_payment_mode: str = Form("Cash"),
    initial_payment_notes: str = Form(""),
    db: Session = Depends(get_db)
):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    risk_info = evaluate_farmer_risk(sales_count=1, repayment_days=15, advance_ratio=0.1)

    party = Party(
        user_id=user.id,
        name=name.strip(),
        mobile=mobile.strip(),
        cnic=cnic.strip(),
        address=address.strip(),
        party_type=party_type,
        opening_balance=opening_balance,
        balance_type=balance_type,
        credit_risk_score=risk_info["score"],
        risk_level=risk_info["risk_label"]
    )
    db.add(party)
    db.commit()
    db.refresh(party)

    today_str = datetime.date.today().strftime("%Y-%m-%d")

    if opening_balance > 0:
        debit = opening_balance if balance_type == "Receivable" else 0.0
        credit = opening_balance if balance_type == "Payable" else 0.0
        add_ledger_entry(
            db=db,
            party_id=party.id,
            date_str=today_str,
            description=f"Opening Balance ({balance_type})",
            debit=debit,
            credit=credit,
            reference_type="Opening",
            user_id=user.id
        )

    if initial_payment_amount > 0:
        voucher_no = f"PAY-{int(datetime.datetime.now().timestamp())}"
        pmt_notes = initial_payment_notes or ("Initial Payment Given (Diye)" if initial_payment_type == "Payment" else "Initial Payment Received (Vasooli/Liye)")
        payment = Payment(
            user_id=user.id,
            voucher_no=voucher_no,
            date=today_str,
            party_id=party.id,
            payment_type=initial_payment_type,
            payment_mode=initial_payment_mode,
            amount=initial_payment_amount,
            reference_no="",
            notes=pmt_notes
        )
        db.add(payment)
        db.commit()

        debit = initial_payment_amount if initial_payment_type == "Payment" else 0.0
        credit = 0.0 if initial_payment_type == "Payment" else initial_payment_amount
        desc = "Cash Payment Given (Diye)" if initial_payment_type == "Payment" else "Cash Payment Received (Vasooli/Liye)"

        add_ledger_entry(
            db=db,
            party_id=party.id,
            date_str=today_str,
            description=f"{desc} [{initial_payment_mode}] - {pmt_notes}",
            debit=debit,
            credit=credit,
            reference_type="Payment",
            reference_id=payment.id,
            user_id=user.id
        )

    return RedirectResponse(url="/parties", status_code=303)

@app.post("/parties/delete/{party_id}")
def delete_party(party_id: int, request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    party = db.query(Party).filter(Party.id == party_id, Party.user_id == user.id).first()
    if not party:
        raise HTTPException(status_code=404, detail="Account not found")

    db.query(LedgerEntry).filter(LedgerEntry.party_id == party_id, LedgerEntry.user_id == user.id).delete(synchronize_session=False)
    db.query(Payment).filter(Payment.party_id == party_id, Payment.user_id == user.id).delete(synchronize_session=False)
    db.query(Settlement).filter(Settlement.farmer_id == party_id, Settlement.user_id == user.id).delete(synchronize_session=False)
    db.query(Sale).filter(Sale.buyer_id == party_id, Sale.user_id == user.id).delete(synchronize_session=False)
    db.query(FasalReceiving).filter(FasalReceiving.farmer_id == party_id, FasalReceiving.user_id == user.id).delete(synchronize_session=False)
    db.delete(party)
    db.commit()

    return RedirectResponse(url="/parties", status_code=303)

@app.get("/receiving", response_class=HTMLResponse)
def receiving_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    farmers = db.query(Party).filter(Party.user_id == user.id, Party.party_type == "Farmer").all()
    crops = db.query(Crop).filter(Crop.user_id == user.id).all()
    if not crops:
        crops = db.query(Crop).filter(Crop.user_id == None).all()

    receivings = db.query(FasalReceiving).filter(FasalReceiving.user_id == user.id).order_by(FasalReceiving.id.desc()).all()

    return templates.TemplateResponse(
        request=request,
        name="receiving.html",
        context={
            "current_user": user,
            "farmers": farmers,
            "crops": crops,
            "receivings": receivings,
            "active_tab": "receiving"
        }
    )

@app.post("/receiving/add")
def add_receiving(
    request: Request,
    farmer_id: int = Form(...),
    crop_id: int = Form(...),
    bags: int = Form(0),
    gross_weight: float = Form(...),
    tare_weight: float = Form(0.0),
    moisture_percent: float = Form(0.0),
    deduction_kg: float = Form(0.0),
    bardana_charge: float = Form(0.0),
    transport_charge: float = Form(0.0),
    db: Session = Depends(get_db)
):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    net_weight = max(0.0, gross_weight - tare_weight)
    final_weight = max(0.0, net_weight - deduction_kg)
    date_str = datetime.date.today().strftime("%Y-%m-%d")
    receipt_no = f"REC-{int(datetime.datetime.now().timestamp())}"

    rec = FasalReceiving(
        user_id=user.id,
        receipt_no=receipt_no,
        date=date_str,
        farmer_id=farmer_id,
        crop_id=crop_id,
        bags=bags,
        gross_weight=gross_weight,
        tare_weight=tare_weight,
        net_weight=net_weight,
        moisture_percent=moisture_percent,
        deduction_kg=deduction_kg,
        final_weight=final_weight,
        bardana_charge=bardana_charge,
        transport_charge=transport_charge,
        status="Received"
    )
    db.add(rec)
    db.commit()

    return RedirectResponse(url="/sales", status_code=303)

@app.get("/sales", response_class=HTMLResponse)
def sales_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    buyers = db.query(Party).filter(Party.user_id == user.id, Party.party_type == "Buyer").all()
    pending_receivings = (
        db.query(FasalReceiving)
        .filter(FasalReceiving.user_id == user.id, FasalReceiving.status.in_(["Received", "Partially Sold"]))
        .all()
    )
    sales = db.query(Sale).filter(Sale.user_id == user.id).order_by(Sale.id.desc()).all()

    return templates.TemplateResponse(
        request=request,
        name="sales.html",
        context={
            "current_user": user,
            "buyers": buyers,
            "pending_receivings": pending_receivings,
            "sales": sales,
            "active_tab": "sales"
        }
    )

@app.post("/sales/process")
def process_sale_route(
    request: Request,
    receiving_id: int = Form(...),
    buyer_id: int = Form(...),
    sale_rate_per_kg: float = Form(...),
    commission_type: str = Form("percentage"),
    commission_rate: float = Form(2.0),
    approved_expenses: float = Form(0.0),
    advance_payment_made: float = Form(0.0),
    notes: str = Form(""),
    sale_quantity_kg: Optional[float] = Form(None),
    db: Session = Depends(get_db)
):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    try:
        sale, settlement = process_sale_and_settlement(
            db=db,
            receiving_id=receiving_id,
            buyer_id=buyer_id,
            sale_rate_per_kg=sale_rate_per_kg,
            commission_type=commission_type,
            commission_rate=commission_rate,
            approved_expenses=approved_expenses,
            advance_payment_made=advance_payment_made,
            notes=notes,
            sale_quantity_kg=sale_quantity_kg,
            user_id=user.id
        )
        return RedirectResponse(url=f"/settlement/voucher/{settlement.id}", status_code=303)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/settlement/voucher/{settlement_id}", response_class=HTMLResponse)
def view_settlement_voucher(settlement_id: int, request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    settlement = db.query(Settlement).filter(Settlement.id == settlement_id, Settlement.user_id == user.id).first()
    if not settlement:
        raise HTTPException(status_code=404, detail="Settlement record not found")

    return templates.TemplateResponse(
        request=request,
        name="voucher.html",
        context={
            "current_user": user,
            "s": settlement,
            "active_tab": "sales"
        }
    )

@app.get("/ledger", response_class=HTMLResponse)
def ledger_page(request: Request, party_id: Optional[int] = None, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    parties = db.query(Party).filter(Party.user_id == user.id).order_by(Party.name.asc()).all()
    selected_party = None
    entries = []

    if party_id:
        selected_party = db.query(Party).filter(Party.id == party_id, Party.user_id == user.id).first()
        if selected_party:
            entries = get_party_ledger(db, party_id, user_id=user.id)
    elif parties:
        selected_party = parties[0]
        entries = get_party_ledger(db, selected_party.id, user_id=user.id)

    return templates.TemplateResponse(
        request=request,
        name="ledger.html",
        context={
            "current_user": user,
            "parties": parties,
            "selected_party": selected_party,
            "entries": entries,
            "active_tab": "ledger"
        }
    )

@app.get("/payments", response_class=HTMLResponse)
def payments_page(
    request: Request,
    party_id: Optional[int] = None,
    payment_type: Optional[str] = None,
    open_modal: Optional[bool] = Query(False),
    db: Session = Depends(get_db)
):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    query = db.query(Payment).filter(Payment.user_id == user.id)
    if party_id:
        query = query.filter(Payment.party_id == party_id)
    if payment_type and payment_type != "All":
        query = query.filter(Payment.payment_type == payment_type)
    
    payments = query.order_by(Payment.id.desc()).all()
    parties = db.query(Party).filter(Party.user_id == user.id).order_by(Party.name.asc()).all()

    auto_open = bool(open_modal or (party_id is not None))

    return templates.TemplateResponse(
        request=request,
        name="payments.html",
        context={
            "current_user": user,
            "payments": payments,
            "parties": parties,
            "selected_party_id": party_id,
            "selected_type": payment_type or "All",
            "auto_open_modal": auto_open,
            "active_tab": "payments"
        }
    )

@app.post("/payments/add")
def add_payment(
    request: Request,
    party_id: int = Form(...),
    payment_type: str = Form(...),
    payment_mode: str = Form("Cash"),
    amount: float = Form(...),
    reference_no: str = Form(""),
    notes: str = Form(""),
    db: Session = Depends(get_db)
):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    date_str = datetime.date.today().strftime("%Y-%m-%d")
    voucher_no = f"PAY-{int(datetime.datetime.now().timestamp())}"

    payment = Payment(
        user_id=user.id,
        voucher_no=voucher_no,
        date=date_str,
        party_id=party_id,
        payment_type=payment_type,
        payment_mode=payment_mode,
        amount=amount,
        reference_no=reference_no,
        notes=notes
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)

    if payment_type == "Payment":
        debit = amount
        credit = 0.0
        desc = f"Cash Payment Given (Diye) [{payment_mode}] - {notes or 'Direct Payment'}"
    else:
        debit = 0.0
        credit = amount
        desc = f"Cash Payment Received (Vasooli/Liye) [{payment_mode}] - {notes or 'Direct Receipt'}"

    add_ledger_entry(
        db=db,
        party_id=party_id,
        date_str=date_str,
        description=desc,
        debit=debit,
        credit=credit,
        reference_type="Payment",
        reference_id=payment.id,
        user_id=user.id
    )

    return RedirectResponse(url=f"/payments?party_id={party_id}", status_code=303)

@app.get("/reports", response_class=HTMLResponse)
def reports_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    sales = db.query(Sale).filter(Sale.user_id == user.id).all()
    receivings = db.query(FasalReceiving).filter(FasalReceiving.user_id == user.id).all()
    settlements = db.query(Settlement).filter(Settlement.user_id == user.id).all()
    parties = db.query(Party).filter(Party.user_id == user.id).all()

    total_sales_val = sum(s.total_sale_amount for s in sales)
    total_commission_val = sum(s.commission_amount for s in sales)
    total_settled_val = sum(st.net_farmer_payable for st in settlements)

    return templates.TemplateResponse(
        request=request,
        name="reports.html",
        context={
            "current_user": user,
            "total_sales_val": total_sales_val,
            "total_commission_val": total_commission_val,
            "total_settled_val": total_settled_val,
            "sales": sales,
            "parties": parties,
            "active_tab": "reports"
        }
    )

# ==================== ML API ENDPOINTS ====================

@app.get("/api/ml/predict-price")
def api_predict_price(crop_id: int = Query(...), days_ahead: int = Query(7)):
    return predict_crop_price(crop_id=crop_id, days_ahead=days_ahead)

@app.get("/api/ml/farmer-risk/{farmer_id}")
def api_farmer_risk(farmer_id: int, request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    user_id = user.id if user else None

    query = db.query(Party).filter(Party.id == farmer_id, Party.party_type == "Farmer")
    if user_id:
        query = query.filter(Party.user_id == user_id)
    farmer = query.first()

    if not farmer:
        raise HTTPException(status_code=404, detail="Farmer not found")

    st_query = db.query(Settlement).filter(Settlement.farmer_id == farmer_id)
    if user_id:
        st_query = st_query.filter(Settlement.user_id == user_id)
    sales_count = st_query.count()

    payments_count = db.query(Payment).filter(Payment.party_id == farmer_id).count()

    risk_info = evaluate_farmer_risk(
        sales_count=max(1, sales_count),
        repayment_days=max(5, 30 - payments_count * 2),
        advance_ratio=0.10 if sales_count > 2 else 0.25
    )

    farmer.credit_risk_score = risk_info["score"]
    farmer.risk_level = risk_info["risk_label"]
    db.commit()

    return risk_info
