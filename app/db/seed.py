from app.db.database import SessionLocal, engine, Base

def seed_initial_data():
    """
    Ensures all database tables are created cleanly without inserting fake demo data.
    """
    Base.metadata.create_all(bind=engine)
    print("Database tables initialized cleanly without fake data.")

if __name__ == "__main__":
    seed_initial_data()
