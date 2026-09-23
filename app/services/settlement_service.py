import datetime
from sqlalchemy.orm import Session
from app.db.models import Sale, FasalReceiving, Settlement, Payment, Expense, Party
from app.services.ledger_service import add_ledger_entry

from typing import Optional

def calculate_commission(total_sale: float, quantity_kg: float, comm_type: str, comm_rate: float) -> float:
    if comm_type == "percentage":
        return (total_sale * comm_rate) / 100.0
    elif comm_type == "per_kg":
        return quantity_kg * comm_rate
    elif comm_type == "fixed":
        return comm_rate
    return 0.0

def process_sale_and_settlement(
    db: Session,
    receiving_id: int,
    buyer_id: int,
    sale_rate_per_kg: float,
    commission_type: str,
    commission_rate: float,
    approved_expenses: float,
    advance_payment_made: float,
    notes: str = "",
    user_id: Optional[int] = None
):
    query = db.query(FasalReceiving).filter(FasalReceiving.id == receiving_id)
    if user_id:
        query = query.filter(FasalReceiving.user_id == user_id)
    receiving = query.first()
    if not receiving:
        raise ValueError("Receiving record not found")

    uid = user_id or receiving.user_id
    quantity_kg = receiving.final_weight if receiving.final_weight > 0 else receiving.net_weight
    total_sale = quantity_kg * sale_rate_per_kg

    comm_amount = calculate_commission(total_sale, quantity_kg, commission_type, commission_rate)
    net_sale = total_sale - comm_amount

    date_str = datetime.date.today().strftime("%Y-%m-%d")
    sale_no = f"SALE-{int(datetime.datetime.now().timestamp())}"

    sale = Sale(
        user_id=uid,
        sale_no=sale_no,
        date=date_str,
        buyer_id=buyer_id,
        receiving_id=receiving_id,
        crop_id=receiving.crop_id,
        quantity_kg=quantity_kg,
        sale_rate_per_kg=sale_rate_per_kg,
        total_sale_amount=total_sale,
        commission_type=commission_type,
        commission_rate=commission_rate,
        commission_amount=comm_amount,
        net_sale_amount=net_sale
    )
    db.add(sale)
    db.commit()
    db.refresh(sale)

    # Update receiving status
    receiving.status = "Settled"
    db.commit()

    # Calculate Farmer Net Payable
    net_farmer_payable = total_sale - comm_amount - approved_expenses
    remaining_balance = net_farmer_payable - advance_payment_made

    settlement_no = f"SETTLE-{int(datetime.datetime.now().timestamp())}"
    settlement = Settlement(
        user_id=uid,
        settlement_no=settlement_no,
        date=date_str,
        farmer_id=receiving.farmer_id,
        sale_id=sale.id,
        gross_sale_amount=total_sale,
        commission_deducted=comm_amount,
        expenses_deducted=approved_expenses,
        net_farmer_payable=net_farmer_payable,
        amount_paid=advance_payment_made,
        remaining_balance=remaining_balance,
        notes=notes
    )
    db.add(settlement)
    db.commit()
    db.refresh(settlement)

    # 1. Update Buyer Ledger (Buyer Debited for Total Sale)
    add_ledger_entry(
        db=db,
        party_id=buyer_id,
        date_str=date_str,
        description=f"Crop Purchase ({quantity_kg} KG @ Rs.{sale_rate_per_kg})",
        debit=total_sale,
        credit=0.0,
        reference_type="Sale",
        reference_id=sale.id,
        user_id=uid
    )

    # 2. Update Farmer Ledger (Farmer Credited for Net Settlement)
    add_ledger_entry(
        db=db,
        party_id=receiving.farmer_id,
        date_str=date_str,
        description=f"Fasal Sale Settlement (Sale Rs.{total_sale} - Comm Rs.{comm_amount} - Exp Rs.{approved_expenses})",
        debit=0.0,
        credit=net_farmer_payable,
        reference_type="Settlement",
        reference_id=settlement.id,
        user_id=uid
    )

    # 3. If payment was made to Farmer, log Payment & Ledger Entry
    if advance_payment_made > 0:
        voucher_no = f"PAY-{int(datetime.datetime.now().timestamp())}"
        payment = Payment(
            user_id=uid,
            voucher_no=voucher_no,
            date=date_str,
            party_id=receiving.farmer_id,
            payment_type="Payment",
            payment_mode="Cash",
            amount=advance_payment_made,
            notes=f"Settlement Payment for {settlement_no}"
        )
        db.add(payment)
        db.commit()

        add_ledger_entry(
            db=db,
            party_id=receiving.farmer_id,
            date_str=date_str,
            description=f"Cash Payment against Settlement {settlement_no}",
            debit=advance_payment_made,
            credit=0.0,
            reference_type="Payment",
            reference_id=payment.id,
            user_id=uid
        )

    return sale, settlement

