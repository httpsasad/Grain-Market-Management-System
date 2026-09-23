import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.db.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    shop_name = Column(String(100), nullable=False)
    owner_name = Column(String(100), nullable=False)
    mobile = Column(String(20), nullable=True)
    city = Column(String(50), default="Sargodha")
    hashed_password = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    parties = relationship("Party", back_populates="user", cascade="all, delete-orphan")
    crops = relationship("Crop", back_populates="user", cascade="all, delete-orphan")
    receivings = relationship("FasalReceiving", back_populates="user", cascade="all, delete-orphan")
    sales = relationship("Sale", back_populates="user", cascade="all, delete-orphan")
    settlements = relationship("Settlement", back_populates="user", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="user", cascade="all, delete-orphan")
    expenses = relationship("Expense", back_populates="user", cascade="all, delete-orphan")
    ledger_entries = relationship("LedgerEntry", back_populates="user", cascade="all, delete-orphan")

class Party(Base):
    __tablename__ = "parties"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    name = Column(String(100), nullable=False, index=True)
    mobile = Column(String(20), nullable=True)
    cnic = Column(String(20), nullable=True)
    address = Column(String(200), nullable=True)
    party_type = Column(String(20), nullable=False) # 'Farmer', 'Buyer', 'Supplier'
    opening_balance = Column(Float, default=0.0) # Rs.
    balance_type = Column(String(20), default="Receivable") # 'Receivable' (Lena Hai), 'Payable' (Dena Hai)
    credit_risk_score = Column(Float, default=85.0) # ML Score (0-100)
    risk_level = Column(String(20), default="Low Risk") # 'Low Risk', 'Medium Risk', 'High Risk'
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="parties")
    receivings = relationship("FasalReceiving", back_populates="farmer")
    sales = relationship("Sale", back_populates="buyer")
    settlements = relationship("Settlement", back_populates="farmer")
    payments = relationship("Payment", back_populates="party")
    ledger_entries = relationship("LedgerEntry", back_populates="party")

class Crop(Base):
    __tablename__ = "crops"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    name = Column(String(50), nullable=False) # Gandum, Chana, Cotton, Rice, Maize
    variety = Column(String(50), default="Super")
    unit_default = Column(String(20), default="Mann") # KG, Mann (40kg), Ton (1000kg)
    current_market_rate = Column(Float, default=250.0) # per KG

    user = relationship("User", back_populates="crops")
    receivings = relationship("FasalReceiving", back_populates="crop")
    sales = relationship("Sale", back_populates="crop")

class FasalReceiving(Base):
    __tablename__ = "fasal_receivings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    receipt_no = Column(String(30), index=True)
    date = Column(String(10), nullable=False) # YYYY-MM-DD
    farmer_id = Column(Integer, ForeignKey("parties.id"), nullable=False)
    crop_id = Column(Integer, ForeignKey("crops.id"), nullable=False)
    bags = Column(Integer, default=0)
    gross_weight = Column(Float, default=0.0) # KG
    tare_weight = Column(Float, default=0.0) # KG
    net_weight = Column(Float, default=0.0) # KG
    moisture_percent = Column(Float, default=0.0)
    deduction_kg = Column(Float, default=0.0)
    final_weight = Column(Float, default=0.0) # KG
    bardana_charge = Column(Float, default=0.0)
    transport_charge = Column(Float, default=0.0)
    status = Column(String(20), default="Received") # 'Received', 'Sold', 'Settled'
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="receivings")
    farmer = relationship("Party", back_populates="receivings")
    crop = relationship("Crop", back_populates="receivings")
    sale = relationship("Sale", back_populates="receiving", uselist=False)

class Sale(Base):
    __tablename__ = "sales"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    sale_no = Column(String(30), index=True)
    date = Column(String(10), nullable=False)
    buyer_id = Column(Integer, ForeignKey("parties.id"), nullable=False)
    receiving_id = Column(Integer, ForeignKey("fasal_receivings.id"), nullable=True)
    crop_id = Column(Integer, ForeignKey("crops.id"), nullable=False)
    quantity_kg = Column(Float, nullable=False)
    sale_rate_per_kg = Column(Float, nullable=False)
    total_sale_amount = Column(Float, nullable=False) # quantity * rate
    commission_type = Column(String(20), default="percentage") # 'percentage', 'per_kg', 'fixed'
    commission_rate = Column(Float, default=2.0)
    commission_amount = Column(Float, default=0.0)
    net_sale_amount = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="sales")
    buyer = relationship("Party", back_populates="sales")
    receiving = relationship("FasalReceiving", back_populates="sale")
    crop = relationship("Crop", back_populates="sales")
    settlement = relationship("Settlement", back_populates="sale", uselist=False)

class Settlement(Base):
    __tablename__ = "settlements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    settlement_no = Column(String(30), index=True)
    date = Column(String(10), nullable=False)
    farmer_id = Column(Integer, ForeignKey("parties.id"), nullable=False)
    sale_id = Column(Integer, ForeignKey("sales.id"), nullable=False)
    gross_sale_amount = Column(Float, nullable=False)
    commission_deducted = Column(Float, default=0.0)
    expenses_deducted = Column(Float, default=0.0)
    net_farmer_payable = Column(Float, nullable=False)
    amount_paid = Column(Float, default=0.0)
    remaining_balance = Column(Float, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="settlements")
    farmer = relationship("Party", back_populates="settlements")
    sale = relationship("Sale", back_populates="settlement")

class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    voucher_no = Column(String(30), index=True)
    date = Column(String(10), nullable=False)
    party_id = Column(Integer, ForeignKey("parties.id"), nullable=False)
    payment_type = Column(String(20), nullable=False) # 'Payment' (Paid out), 'Receipt' (Received in)
    payment_mode = Column(String(20), default="Cash") # 'Cash', 'Bank', 'Cheque'
    amount = Column(Float, nullable=False)
    reference_no = Column(String(50), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="payments")
    party = relationship("Party", back_populates="payments")

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    date = Column(String(10), nullable=False)
    category = Column(String(50), nullable=False) # Transport, Labour, Loading, Rent, Misc
    amount = Column(Float, nullable=False)
    party_id = Column(Integer, ForeignKey("parties.id"), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="expenses")

class LedgerEntry(Base):
    __tablename__ = "ledger_entries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    date = Column(String(10), nullable=False)
    party_id = Column(Integer, ForeignKey("parties.id"), nullable=False)
    description = Column(String(200), nullable=False)
    debit = Column(Float, default=0.0)  # Received / Charged to party
    credit = Column(Float, default=0.0) # Paid / Settled for party
    running_balance = Column(Float, nullable=False)
    reference_type = Column(String(30), nullable=True) # 'Sale', 'Settlement', 'Payment', 'Opening'
    reference_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="ledger_entries")
    party = relationship("Party", back_populates="ledger_entries")

