from typing import Optional, List
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
    Debit (+): Increases receivable (Lena Hai) / Paid out to party.
    Credit (-): Increases payable (Dena Hai) / Received from party.
    """
    party_query = db.query(Party).filter(Party.id == party_id)
    if user_id:
        party_query = party_query.filter(Party.user_id == user_id)
    party = party_query.first()
    if not party:
        raise ValueError("Party not found")

    uid = user_id or party.user_id

    # Create new entry first
    entry = LedgerEntry(
        user_id=uid,
        date=date_str,
        party_id=party_id,
        description=description,
        debit=debit,
        credit=credit,
        running_balance=0.0,
        reference_type=reference_type,
        reference_id=reference_id
    )
    db.add(entry)
    db.commit()

    # Recalculate running balance across all entries for consistency
    recalculate_party_ledger(db, party_id=party_id, user_id=uid)
    db.refresh(entry)
    return entry

def recalculate_party_ledger(db: Session, party_id: int, user_id: Optional[int] = None) -> List[LedgerEntry]:
    """
    Recalculates running balances chronologically for a party's ledger.
    """
    query = db.query(LedgerEntry).filter(LedgerEntry.party_id == party_id)
    if user_id:
        query = query.filter(LedgerEntry.user_id == user_id)

    entries = query.order_by(LedgerEntry.date.asc(), LedgerEntry.id.asc()).all()

    running = 0.0
    for entry in entries:
        running = running + entry.debit - entry.credit
        entry.running_balance = round(running, 2)

    db.commit()
    return entries

def get_party_ledger(db: Session, party_id: int, user_id: Optional[int] = None) -> List[LedgerEntry]:
    query = db.query(LedgerEntry).filter(LedgerEntry.party_id == party_id)
    if user_id:
        query = query.filter(LedgerEntry.user_id == user_id)
    return query.order_by(LedgerEntry.date.asc(), LedgerEntry.id.asc()).all()
