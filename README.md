# 🌾 Grain Market Management System (AI Mandi ERP & Multi-Shop Platform)

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100%2B-009688.svg)](https://fastapi.tiangolo.com/)
[![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-2.0%2B-red.svg)](https://www.sqlalchemy.org/)
[![Scikit-Learn](https://img.shields.io/badge/Scikit--Learn-1.2%2B-orange.svg)](https://scikit-learn.org/)
[![TailwindCSS](https://img.shields.io/badge/TailwindCSS-3.0-38BDF8.svg)](https://tailwindcss.com/)

A state-of-the-art, AI-powered ERP system designed specifically for **Galla Mandi (Grain Market) Commission Agents, Arhtis, and Grain Traders**. 

This system allows multiple shopkeepers to create their own accounts, manage their shop branding, and keep their financial records (Khata Ledger, Fasal Receivings, Sales, Settlements, Payments, and Reports) completely private and isolated.

---

## ✨ Key Features

### 🏢 1. Multi-User & Multi-Shop Platform (Multi-Tenancy)
- **Shopkeeper Signup (`/signup`)**: Register a new shop account with Shop Name, Owner Name, Mobile Number, City, and Password.
- **Shopkeeper Login (`/login`)**: Secure session-based authentication.
- **Custom Voucher Branding (`/profile`)**: Easily edit Shop Name, Malik Name, Mobile Number, and City which automatically print on customer thermal receipts and settlement slips.
- **100% Data Isolation**: Complete privacy ensuring Shop A cannot see Shop B's parties, sales, ledger entries, or reports.

### 🌾 2. Fasal Receiving (Aamad Record)
- Record incoming crops (Wheat, Chickpeas, Cotton, Rice, Maize, etc.) from farmers.
- Automated weight calculation: Gross Weight, Tare Weight, Net Weight, Moisture Percentage, Deduction (Katt), and Final Weight.

### 🤝 3. Sales & Commission Settlement (Bikri & Hisab Clear)
- Process crop sales to buyers/mills with dynamic commission options (**Percentage**, **Per-KG Rate**, or **Fixed Amount**).
- Deduct approved expenses (Labour, Loading, Bardana, Transport).
- Auto-calculate Net Farmer Payable and Remaining Balance.
- Instant double-entry ledger postings for both Buyer and Farmer.

### 🧾 4. Printable Thermal Voucher Slips
- Generates professional settlement slips (`/settlement/voucher/{id}`) formatted for thermal slip printers.
- Includes full transaction breakdown, deductions, and shop branding header.

### 📖 5. Double-Entry Running Khata Ledger
- Real-time tracking of **Receivables (Lena Hai)** and **Payables (Dena Hai)** for all farmers, buyers, and suppliers.
- Detailed date-wise transaction history with debit, credit, and running balance calculation.

### 💸 6. Cash & Bank Payment Vouchers
- Record cash given (Payments/Diye) and cash received (Receipts/Vasooli).
- Automatically updates party khata running balance.

### 📈 7. ML Crop Price Prediction Engine
- Integrated Machine Learning model (Scikit-Learn / Random Forest) trained on historical mandi market rates.
- Provides 7-day ahead price forecasts per KG and per Mann (40 KG) with confidence scores.

### 🛡️ 8. ML Farmer Credit Risk Scorer
- Automated credit evaluation model scoring farmers (0-100) and assigning risk categories (**Low Risk (Safe)**, **Medium Risk**, **High Risk**).
- Evaluates repayment frequency, advance payment ratios, and historical sales volume.

### 🌐 9. Urdu / English Bilingual Interface
- Modern glassmorphism UI with responsive design.
- Built-in one-click Urdu (Noto Nastaliq) / English language toggle.

---

## 🛠️ Technology Stack

- **Backend Framework**: [FastAPI](https://fastapi.tiangolo.com/) (Async Python)
- **Database & ORM**: SQLite + [SQLAlchemy 2.0](https://www.sqlalchemy.org/)
- **Templating Engine**: [Jinja2](https://jinja.net.au/)
- **Machine Learning**: [Scikit-Learn](https://scikit-learn.org/), [Pandas](https://pandas.pydata.org/), [NumPy](https://numpy.org/)
- **Frontend Styling**: Vanilla CSS, [Tailwind CSS](https://tailwindcss.com/), [FontAwesome 6](https://fontawesome.com/)
- **Authentication**: PBKDF2 SHA-256 password hashing & secure HTTPOnly session tokens

---

## 📂 Project Architecture

```
Grain Market Management System/
│
├── app/
│   ├── db/
│   │   ├── database.py       # SQLAlchemy engine & session setup
│   │   ├── models.py         # DB Models (User, Party, Crop, Receiving, Sale, Settlement, Payment, Ledger)
│   │   └── seed.py           # Database initial seeding script
│   │
│   ├── services/
│   │   ├── auth_service.py   # Hashing, session tokens, FastAPI dependencies
│   │   ├── ledger_service.py # Double-entry ledger calculation logic
│   │   └── settlement_service.py # Sale & settlement processing logic
│   │
│   ├── ml/
│   │   ├── price_predictor.py # Machine Learning crop price forecaster
│   │   └── credit_scorer.py   # Machine Learning farmer risk evaluator
│   │
│   ├── templates/            # HTML Jinja2 Templates
│   │   ├── base.html         # Main layout & navigation header
│   │   ├── login.html        # Shopkeeper login page
│   │   ├── signup.html       # Shop registration page
│   │   ├── profile.html      # Shop settings & voucher branding
│   │   ├── index.html        # Dashboard with KPIs & ML predictions
│   │   ├── parties.html      # Farmer & Buyer management
│   │   ├── receiving.html    # Fasal receiving entry
│   │   ├── sales.html        # Sale & commission processing
│   │   ├── voucher.html      # Printable thermal voucher slip
│   │   ├── ledger.html       # Running Khata ledger view
│   │   ├── payments.html     # Cash payment & receipt vouchers
│   │   └── reports.html      # Business summary reports
│   │
│   ├── static/               # Custom CSS & Static Assets
│   └── main.py               # FastAPI application & route controllers
│
├── models_saved/             # Saved ML model artifacts (.joblib)
├── tests/
│   └── test_system.py        # Automated Pytest suite (Unit & Multi-Tenancy tests)
├── .gitignore                # Git ignore configuration
├── requirements.txt          # Python dependencies
├── run.py                    # Server startup script
└── README.md                 # Project documentation
```

---

## ⚙️ Installation & Setup

### Prerequisites
- Python 3.10 or higher
- Git

### 1. Clone Repository
```bash
git clone https://github.com/httpsasad/Grain-Market-Management-System.git
cd Grain-Market-Management-System
```

### 2. Create Virtual Environment & Install Dependencies
```bash
# On Windows
python -m venv venv
venv\Scripts\activate

# Install requirements
pip install -r requirements.txt
```

### 3. Initialize Database & Seed Data
```bash
python -c "from app.db.seed import seed_initial_data; seed_initial_data()"
```

### 4. Run Application Server
```bash
python run.py
```
Or using Uvicorn directly:
```bash
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Open your browser and navigate to **`http://127.0.0.1:8000`**.

---

## 🔑 Default Demo Credentials

You can log in immediately with the pre-configured default demo account or register a new shop:

| Account Type | Username | Password | Shop Name |
| :--- | :--- | :--- | :--- |
| **Demo Shopkeeper** | `shop1` | `password123` | Bismillah Grain Mandi Arhat |

Or visit **`http://127.0.0.1:8000/signup`** to register your own shop!

---

## 🧪 Running Automated Tests

Run the test suite using `pytest`:

```bash
python -m pytest
```

---

## 👤 Author & Maintainer

Developed with ❤️ by **[Asad](https://github.com/httpsasad)**.

If you find this project helpful, please give it a ⭐ star on GitHub!
