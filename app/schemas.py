from pydantic import BaseModel, Field
from typing import Optional, List

class LoginRequest(BaseModel):
    username: str
    password: str

class SignupRequest(BaseModel):
    username: str
    shop_name: str
    owner_name: str
    mobile: str
    city: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    username: str
    shop_name: str
    owner_name: str

class UserProfileResponse(BaseModel):
    id: int
    username: str
    shop_name: str
    owner_name: str
    mobile: Optional[str] = None
    city: Optional[str] = None

class PartyCreate(BaseModel):
    name: str
    mobile: Optional[str] = ""
    cnic: Optional[str] = ""
    address: Optional[str] = ""
    party_type: str # 'Farmer', 'Buyer', 'Supplier'
    opening_balance: float = 0.0
    balance_type: str = "Receivable" # 'Receivable', 'Payable'
    initial_payment_amount: float = 0.0
    initial_payment_type: str = "Payment"
    initial_payment_mode: str = "Cash"
    initial_payment_notes: str = ""

class PartyUpdate(BaseModel):
    name: str
    mobile: Optional[str] = ""
    cnic: Optional[str] = ""
    address: Optional[str] = ""
    party_type: str # 'Farmer', 'Buyer', 'Supplier'
    opening_balance: float = 0.0
    balance_type: str = "Receivable" # 'Receivable', 'Payable'

class ReceivingCreate(BaseModel):
    farmer_id: int
    crop_id: int
    bags: int = 0
    gross_weight: float
    tare_weight: float = 0.0
    moisture_percent: float = 0.0
    deduction_kg: float = 0.0
    bardana_charge: float = 0.0
    transport_charge: float = 0.0

class ReceivingUpdate(BaseModel):
    farmer_id: int
    crop_id: int
    bags: int = 0
    gross_weight: float
    tare_weight: float = 0.0
    moisture_percent: float = 0.0
    deduction_kg: float = 0.0
    bardana_charge: float = 0.0
    transport_charge: float = 0.0

class SaleProcessRequest(BaseModel):
    receiving_id: int
    buyer_id: int
    sale_rate_per_kg: float
    buyer_commission_type: str = "percentage" # 'percentage', 'per_kg', 'fixed'
    buyer_commission_rate: float = 0.0 # ADDED to Buyer bill
    farmer_commission_type: str = "percentage" # 'percentage', 'per_kg', 'fixed'
    farmer_commission_rate: float = 2.0 # DEDUCTED from Farmer settlement
    commission_type: str = "percentage" # Fallback
    commission_rate: float = 2.0 # Fallback
    mazdoori_type: str = "per_bag" # 'per_bag', 'percentage', 'fixed'
    mazdoori_rate: float = 0.0 # 1. Mazdoori / Palledari
    brokery_type: str = "per_bag" # 'per_bag', 'percentage', 'fixed'
    brokery_rate: float = 0.0 # 2. Brokery / Dalali
    shop_charges_type: str = "per_bag" # 'per_bag', 'percentage', 'fixed'
    shop_charges_rate: float = 0.0 # 3. Shop / Dukan Charges
    approved_expenses: float = 0.0
    advance_payment_made: float = 0.0
    notes: Optional[str] = ""
    sale_quantity_kg: Optional[float] = None

class PaymentCreate(BaseModel):
    party_id: int
    payment_type: str # 'Payment' (Paid out), 'Receipt' (Received in)
    payment_mode: str = "Cash" # 'Cash', 'Bank', 'Cheque'
    amount: float
    reference_no: Optional[str] = ""
    notes: Optional[str] = ""

class ManualLedgerEntryCreate(BaseModel):
    party_id: int
    entry_type: str # 'Debit' (Lena/Paid out) or 'Credit' (Dena/Received in)
    amount: float
    description: str
    date: Optional[str] = None
