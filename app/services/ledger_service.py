from typing import Optional
from sqlalchemy.orm import Session
from app.db.models import Party, LedgerEntry

def add_ledger_entry(
    db: Session,
    party_id: int,
    date_str: str,
    description: str,
    debit: float,
    credit: float,
    reference_type: Optional[str] = None,
    reference_id: Optional[int] = None,
    user_id: Optional[int] = None
) -> LedgerEntry:
    """
    Adds a double-entry transaction record and updates the party's running balance automatically.
    For Farmers/Payables: Credit increases payable amount, Debit decreases it.
    For Buyers/Receivables: Debit increases receivable amount, Credit decreases it.
    """
    party_query = db.query(Party).filter(Party.id == party_id)
    if user_id:
        party_query = party_query.filter(Party.user_id == user_id)
    party = party_query.first()
    if not party:
        raise ValueError("Party not found")

    # Get last ledger entry running balance, or start with opening balance
    last_query = db.query(LedgerEntry).filter(LedgerEntry.party_id == party_id)
    if user_id:
        last_query = last_query.filter(LedgerEntry.user_id == user_id)
    last_entry = last_query.order_by(LedgerEntry.id.desc()).first()

    previous_balance = last_entry.running_balance if last_entry else 0.0

    # Debit increases receivable (+), Credit decreases receivable (-) / increases payable
    new_balance = previous_balance + debit - credit

    entry = LedgerEntry(
        user_id=user_id or party.user_id,
        date=date_str,
        party_id=party_id,
        description=description,
        debit=debit,
        credit=credit,
        running_balance=new_balance,
        reference_type=reference_type,
        reference_id=reference_id
    )

    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry

def get_party_ledger(db: Session, party_id: int, user_id: Optional[int] = None):
    query = db.query(LedgerEntry).filter(LedgerEntry.party_id == party_id)
    if user_id:
        query = query.filter(LedgerEntry.user_id == user_id)
    return query.order_by(LedgerEntry.id.asc()).all()

