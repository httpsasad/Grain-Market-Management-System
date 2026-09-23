from app.db.database import SessionLocal, engine, Base
from app.db.models import User, Crop, Party, LedgerEntry
from app.services.auth_service import hash_password

def seed_initial_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # Seed Default User / Shopkeeper if empty
        default_user = db.query(User).filter(User.username == "shop1").first()
        if not default_user:
            default_user = User(
                username="shop1",
                shop_name="Bismillah Grain Mandi Arhat",
                owner_name="Chaudhry Muhammad Ali",
                mobile="0300-1234567",
                city="Sargodha",
                hashed_password=hash_password("password123")
            )
            db.add(default_user)
            db.commit()
            db.refresh(default_user)
            print(f"Default user '{default_user.username}' created.")

        # Seed Crops if empty for this user
        if db.query(Crop).filter(Crop.user_id == default_user.id).count() == 0:
            crops = [
                Crop(user_id=default_user.id, name="Gandum (Wheat)", variety="Super White", unit_default="Mann", current_market_rate=105.0),
                Crop(user_id=default_user.id, name="Chana (Chickpeas)", variety="Desi Grade A", unit_default="Mann", current_market_rate=225.0),
                Crop(user_id=default_user.id, name="Cotton (Kapas)", variety="Phutti Grade A", unit_default="Mann", current_market_rate=290.0),
                Crop(user_id=default_user.id, name="Rice (Basmati)", variety="Super Kernel", unit_default="Mann", current_market_rate=185.0),
                Crop(user_id=default_user.id, name="Maize (Makai)", variety="Hybrid Yellow", unit_default="Mann", current_market_rate=95.0),
            ]
            db.add_all(crops)
            db.commit()
            print("Initial crops seeded successfully.")

        # Seed Sample Parties if empty for this user
        if db.query(Party).filter(Party.user_id == default_user.id).count() == 0:
            farmer1 = Party(
                user_id=default_user.id,
                name="Chaudhry Muhammad Ali",
                mobile="0300-1234567",
                cnic="35202-1234567-1",
                address="Chak 45/NB, Sargodha",
                party_type="Farmer",
                opening_balance=0.0,
                balance_type="Payable",
                credit_risk_score=92.5,
                risk_level="Low Risk (Safe)"
            )
            farmer2 = Party(
                user_id=default_user.id,
                name="Malik Tariq Mehmood",
                mobile="0301-7654321",
                cnic="35201-9876543-3",
                address="Depalpur, Okara",
                party_type="Farmer",
                opening_balance=50000.0,
                balance_type="Payable",
                credit_risk_score=78.0,
                risk_level="Medium Risk"
            )
            buyer1 = Party(
                user_id=default_user.id,
                name="Al-Rehman Flour Mills",
                mobile="0321-9988776",
                cnic="35202-8877665-5",
                address="Industrial Estate, Multan",
                party_type="Buyer",
                opening_balance=250000.0,
                balance_type="Receivable",
                credit_risk_score=95.0,
                risk_level="Low Risk (Safe)"
            )
            buyer2 = Party(
                user_id=default_user.id,
                name="Ittehad Oil & Feed Traders",
                mobile="0333-4455667",
                cnic="35202-5544332-9",
                address="Grain Market, Faisalabad",
                party_type="Buyer",
                opening_balance=0.0,
                balance_type="Receivable",
                credit_risk_score=88.0,
                risk_level="Low Risk (Safe)"
            )

            db.add_all([farmer1, farmer2, buyer1, buyer2])
            db.commit()

            # Seed Opening Ledger Entries
            entries = [
                LedgerEntry(
                    user_id=default_user.id,
                    date="2026-09-01",
                    party_id=farmer2.id,
                    description="Opening Balance (Advance Payable)",
                    debit=0.0,
                    credit=50000.0,
                    running_balance=-50000.0,
                    reference_type="Opening"
                ),
                LedgerEntry(
                    user_id=default_user.id,
                    date="2026-09-01",
                    party_id=buyer1.id,
                    description="Opening Balance (Receivable)",
                    debit=250000.0,
                    credit=0.0,
                    running_balance=250000.0,
                    reference_type="Opening"
                )
            ]
            db.add_all(entries)
            db.commit()
            print("Initial sample parties & ledger entries seeded successfully.")

    finally:
        db.close()

if __name__ == "__main__":
    seed_initial_data()

