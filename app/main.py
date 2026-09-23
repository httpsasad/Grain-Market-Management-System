import os
import datetime
from typing import Optional
from fastapi import FastAPI, Depends, Request, Form, HTTPException, Query
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
from app.services.ledger_service import add_ledger_entry, get_party_ledger
from app.services.settlement_service import process_sale_and_settlement
from app.ml.price_predictor import predict_crop_price
from app.ml.credit_scorer import evaluate_farmer_risk

# Create Database tables & seed initial data
Base.metadata.create_all(bind=engine)
seed_initial_data()

app = FastAPI(title="Grain Market Management System (Mandi ERP & Multi-Shop)")

# Mount Static Files & Templates
BASE_DIR = os.path.dirname(__file__)
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

# ==================== AUTHENTICATION ROUTES ====================

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
    user = db.query(User).filter(User.username == username.strip()).first()
    if not user or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse(
            request=request,
            name="login.html",
            context={"error": "Ghalat Username ya Password! Baraye meharbani dobara koshish karein."}
        )

    token = create_session_token(user.id)
    response = RedirectResponse(url="/", status_code=303)
    response.set_cookie(key="session_token", value=token, httponly=True, max_age=86400 * 30)
    response.set_cookie(key="user_id", value=str(user.id), httponly=True, max_age=86400 * 30)
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

    # Seed default crop options for the new shopkeeper
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
    response.set_cookie(key="user_id", value=str(new_user.id), httponly=True, max_age=86400 * 30)
    return response

@app.get("/logout")
def logout():
    response = RedirectResponse(url="/login", status_code=303)
    response.delete_cookie("session_token")
    response.delete_cookie("user_id")
    return response

@app.get("/profile", response_class=HTMLResponse)
def profile_page(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    return templates.TemplateResponse(
        request=request,
        name="profile.html",
        context={
            "current_user": user,
            "active_tab": "profile"
        }
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

# ==================== MAIN CORE APP ROUTES ====================

@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request, db: Session = Depends(get_db)):
    user = get_current_user_optional(request, db)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    today_str = datetime.date.today().strftime("%Y-%m-%d")

    # KPIs scoped to current user shop
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

    # Calculate Total Receivables (Lena Hai) & Total Payables (Dena Hai) for this user
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

    # ML Price Predictions for crops
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
        .filter(FasalReceiving.user_id == user.id, FasalReceiving.status == "Received")
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

    # Run ML Risk Scorer for initial farmer rating
    risk_info = evaluate_farmer_risk(sales_count=1, repayment_days=15, advance_ratio=0.1)

    party = Party(
        user_id=user.id,
        name=name,
        mobile=mobile,
        cnic=cnic,
        address=address,
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

    # Initial Opening Balance Ledger Entry
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

    # Initial Payment Entry (Kitny Diye / Kitny Liye)
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
        db.refresh(payment)

        # Add payment to Khata Ledger
        if initial_payment_type == "Payment":
            debit = initial_payment_amount
            credit = 0.0
            desc = f"Cash Payment Given (Diye) [{initial_payment_mode}] - {pmt_notes}"
        else:
            debit = 0.0
            credit = initial_payment_amount
            desc = f"Cash Payment Received (Vasooli/Liye) [{initial_payment_mode}] - {pmt_notes}"

        add_ledger_entry(
            db=db,
            party_id=party.id,
            date_str=today_str,
            description=desc,
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

    # Clean up associated ledger entries & payments & settlements for this user
    db.query(LedgerEntry).filter(LedgerEntry.party_id == party_id, LedgerEntry.user_id == user.id).delete(synchronize_session=False)
    db.query(Payment).filter(Payment.party_id == party_id, Payment.user_id == user.id).delete(synchronize_session=False)
    db.query(Settlement).filter(Settlement.farmer_id == party_id, Settlement.user_id == user.id).delete(synchronize_session=False)

    sales = db.query(Sale).filter(Sale.buyer_id == party_id, Sale.user_id == user.id).all()
    for s in sales:
        db.delete(s)

    receivings = db.query(FasalReceiving).filter(FasalReceiving.farmer_id == party_id, FasalReceiving.user_id == user.id).all()
    for r in receivings:
        db.delete(r)

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
    pending_receivings = db.query(FasalReceiving).filter(FasalReceiving.user_id == user.id, FasalReceiving.status == "Received").all()
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

    # Khata double-entry:
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

    risk_info = evaluate_farmer_risk(
        sales_count=sales_count,
        repayment_days=14,
        advance_ratio=0.15
    )

    farmer.credit_risk_score = risk_info["score"]
    farmer.risk_level = risk_info["risk_label"]
    db.commit()

    return risk_info
