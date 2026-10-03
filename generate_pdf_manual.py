import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY

def build_pdf(filename="Mandi_ERP_Complete_Guide_and_Setup_Manual.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()
    
    # Custom Palette
    c_primary = colors.HexColor("#0F5132")   # Dark Emerald Green
    c_secondary = colors.HexColor("#D4AF37") # Gold
    c_dark = colors.HexColor("#1E293B")      # Slate 800
    c_light_bg = colors.HexColor("#F8FAFC")  # Slate 50
    c_accent_blue = colors.HexColor("#1E40AF")
    c_accent_red = colors.HexColor("#991B1B")

    # Custom Paragraph Styles
    style_title = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontSize=24,
        leading=28,
        textColor=c_primary,
        alignment=TA_CENTER,
        fontName='Helvetica-Bold',
        spaceAfter=4
    )

    style_subtitle = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontSize=12,
        leading=15,
        textColor=colors.HexColor("#475569"),
        alignment=TA_CENTER,
        fontName='Helvetica',
        spaceAfter=15
    )

    style_h1 = ParagraphStyle(
        'Heading1Custom',
        parent=styles['Heading2'],
        fontSize=15,
        leading=18,
        textColor=c_primary,
        fontName='Helvetica-Bold',
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True
    )

    style_h2 = ParagraphStyle(
        'Heading2Custom',
        parent=styles['Heading3'],
        fontSize=12,
        leading=15,
        textColor=c_accent_blue,
        fontName='Helvetica-Bold',
        spaceBefore=10,
        spaceAfter=6,
        keepWithNext=True
    )

    style_body = ParagraphStyle(
        'BodyCustom',
        parent=styles['Normal'],
        fontSize=10,
        leading=14,
        textColor=c_dark,
        fontName='Helvetica',
        spaceAfter=6
    )

    style_body_bold = ParagraphStyle(
        'BodyBoldCustom',
        parent=styles['Normal'],
        fontSize=10,
        leading=14,
        textColor=c_dark,
        fontName='Helvetica-Bold',
        spaceAfter=6
    )

    style_bullet = ParagraphStyle(
        'BulletCustom',
        parent=styles['Normal'],
        fontSize=9.5,
        leading=13.5,
        textColor=c_dark,
        fontName='Helvetica',
        leftIndent=15,
        spaceAfter=4
    )

    style_box = ParagraphStyle(
        'BoxText',
        parent=styles['Normal'],
        fontSize=9.5,
        leading=13.5,
        textColor=c_dark,
        fontName='Helvetica'
    )

    story = []

    # Title Header Banner
    story.append(Paragraph("MANDI ERP - GRAIN MARKET MANAGEMENT SYSTEM", style_title))
    story.append(Paragraph("Complete User Manual, System Mechanics & Client Setup Guide", style_subtitle))
    story.append(HRFlowable(width="100%", thickness=2, color=c_primary, spaceBefore=0, spaceAfter=12))

    # SECTION 1: SYSTEM OVERVIEW
    story.append(Paragraph("1. System Overview & Mandi Business Logic", style_h1))
    story.append(Paragraph(
        "The Grain Market Management System (Mandi ERP) is designed specifically for Commission Agents (Arhtai Shop / غلہ منڈی آرہت) to automate crop receiving, crop sales, multi-party ledger accounts, and custom commission/palledari deductions without manual errors.",
        style_body
    ))

    # 4 Steps Table
    steps_data = [
        [Paragraph("<b>Step</b>", style_body_bold), Paragraph("<b>Mandi Phase</b>", style_body_bold), Paragraph("<b>Description & Operations</b>", style_body_bold)],
        [
            Paragraph("<b>Step 1</b>", style_body_bold),
            Paragraph("<b>Party Accounts<br/>(کھاتے)</b>", style_body_bold),
            Paragraph("Setup accounts for Farmers/Sellers (Zamindar) and Buyers (Mills/Traders). Supports Opening Balances (Receivable / Payable).", style_box)
        ],
        [
            Paragraph("<b>Step 2</b>", style_body_bold),
            Paragraph("<b>Fasal Receiving<br/>(آمد)</b>", style_body_bold),
            Paragraph("Log incoming crop stock brought by Farmer (Crop type, Bags, Gross Wt, Deduction, Net Wt, Manns). No price fixed yet.", style_box)
        ],
        [
            Paragraph("<b>Step 3</b>", style_body_bold),
            Paragraph("<b>Sales & Settlement<br/>(فروخت و حساب)</b>", style_body_bold),
            Paragraph("Sell crop to Buyer @ market rate. System automatically calculates Buyer Bill (+) and Farmer Net Payable (-) after deducting 3 Palledar charges (Mazdoori, Brokery, Shop).", style_box)
        ],
        [
            Paragraph("<b>Step 4</b>", style_body_bold),
            Paragraph("<b>Ledger & Cash<br/>(ادائیگی و وصولی)</b>", style_body_bold),
            Paragraph("Double-entry running khata logs receipts from Buyer (Vasooli) and payments to Farmer (Diye) with printable dual vouchers.", style_box)
        ]
    ]

    t_steps = Table(steps_data, colWidths=[55, 110, 365])
    t_steps.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#E2E8F0")),
        ('TEXTCOLOR', (0,0), (-1,0), c_primary),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E1")),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_steps)
    story.append(Spacer(1, 12))

    # SECTION 2: FORMULA & CALCULATION BREAKDOWN
    story.append(Paragraph("2. Financial Formulas & Calculations", style_h1))
    story.append(Paragraph(
        "Mandi ERP automates dual-entry calculation for both Buyer (Purchaser) and Farmer (Crop Seller):",
        style_body
    ))

    calc_data = [
        [
            Paragraph("<b>BUYER TOTAL BILL FORMULA (+)</b>", ParagraphStyle('BHead', parent=style_body_bold, textColor=c_accent_blue)),
            Paragraph("<b>FARMER NET PAYABLE FORMULA (-)</b>", ParagraphStyle('FHead', parent=style_body_bold, textColor=c_accent_red))
        ],
        [
            Paragraph(
                "<b>Gross Sale</b> = Net Weight (KG) × Rate/KG<br/>"
                "<b>Buyer Comm</b> = Gross Sale × Buyer Comm Rate (%)<br/>"
                "<b>👉 BUYER TOTAL BILL = Gross Sale + Buyer Comm</b><br/>"
                "<i>(Debited to Buyer Ledger: LENA HAI)</i>",
                style_box
            ),
            Paragraph(
                "<b>Gross Sale</b> = Net Weight (KG) × Rate/KG<br/>"
                "<b>(-) Farmer Comm</b> = Gross Sale × Farmer Comm Rate (%)<br/>"
                "<b>(-) 1. Mazdoori / Palledari</b> = Per Bag / Rate<br/>"
                "<b>(-) 2. Brokery / Dalali</b> = Per Bag / Rate<br/>"
                "<b>(-) 3. Shop / Tulai Charges</b> = Per Bag / Rate<br/>"
                "<b>👉 FARMER NET PAYABLE = Gross Sale - Deductions</b><br/>"
                "<i>(Credited to Farmer Ledger: DENA HAI)</i>",
                style_box
            )
        ]
    ]

    t_calc = Table(calc_data, colWidths=[260, 270])
    t_calc.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), colors.HexColor("#EFF6FF")),
        ('BACKGROUND', (1,0), (1,0), colors.HexColor("#FEF2F2")),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#94A3B8")),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_calc)
    story.append(Spacer(1, 10))

    # Example Scenario
    story.append(Paragraph("<b>Practical Numerical Example:</b>", style_body_bold))
    story.append(Paragraph("• <b>Wheat Lot:</b> 100 Bags (4,000 KG / 100 Manns) @ Rs. 4,000/Mann (Rs. 100/KG)", style_bullet))
    story.append(Paragraph("• <b>Gross Crop Sale:</b> 4,000 KG × Rs. 100 = <b>Rs. 400,000</b>", style_bullet))
    story.append(Paragraph("• <b>Buyer Bill:</b> Rs. 400,000 + Rs. 4,000 (1% Buyer Comm) = <b>Rs. 404,000</b> (Buyer Owes You)", style_bullet))
    story.append(Paragraph("• <b>Farmer Settlement:</b> Rs. 400,000 - Rs. 8,000 (2% Comm) - Rs. 2,000 (Mazdoori @ Rs.20/bag) - Rs. 1,000 (Brokery) - Rs. 1,000 (Shop) = <b>Rs. 388,000</b> (You Owe Farmer)", style_bullet))
    story.append(Paragraph("• <b>Your Shop Earnings:</b> Rs. 4,000 (Buyer Comm) + Rs. 8,000 (Farmer Comm) + Rs. 4,000 (Deductions) = <b>Rs. 16,000 Net Profit</b>", style_bullet))

    story.append(PageBreak())

    # SECTION 3: CLIENT LAPTOP INSTALLATION & SETUP GUIDE
    story.append(Paragraph("3. Client Laptop Installation & 1-Click Desktop Setup", style_h1))
    story.append(Paragraph(
        "Follow these simple steps to set up and run Mandi ERP on your client's Windows laptop without creating a new codebase:",
        style_body
    ))

    setup_steps = [
        [Paragraph("<b>Step</b>", style_body_bold), Paragraph("<b>Action Item</b>", style_body_bold), Paragraph("<b>Instructions</b>", style_body_bold)],
        [
            Paragraph("<b>1</b>", style_body_bold),
            Paragraph("<b>Copy Folder</b>", style_body_bold),
            Paragraph("Copy the entire project folder (<code>Grain Market Management System</code>) to the client's laptop (e.g. <code>D:\\Grain Market Management System</code> or <code>C:\\Mandi_ERP</code>).", style_box)
        ],
        [
            Paragraph("<b>2</b>", style_body_bold),
            Paragraph("<b>Install Python</b>", style_body_bold),
            Paragraph("Download & install Python 3.10+ from python.org. <br/><b>CRITICAL:</b> Check the box <i>'Add python.exe to PATH'</i> during installation.", style_box)
        ],
        [
            Paragraph("<b>3</b>", style_body_bold),
            Paragraph("<b>One-Time Setup</b>", style_body_bold),
            Paragraph("Double-click on <b><code>Setup_Requirements.bat</code></b> inside the folder. It will install all required Python packages automatically.", style_box)
        ],
        [
            Paragraph("<b>4</b>", style_body_bold),
            Paragraph("<b>Desktop Shortcut</b>", style_body_bold),
            Paragraph("Double-click on <b><code>Create_Desktop_Shortcut.bat</code></b>. It will instantly generate a <b>'Mandi ERP'</b> shortcut on the Windows Desktop.", style_box)
        ],
        [
            Paragraph("<b>5</b>", style_body_bold),
            Paragraph("<b>Daily Usage</b>", style_body_bold),
            Paragraph("Client double-clicks on the <b>'Mandi ERP' Desktop Shortcut</b> (or <code>Start_Mandi_ERP.bat</code>). The Web App will auto-open in Google Chrome at <code>http://localhost:8000</code>.", style_box)
        ]
    ]

    t_setup = Table(setup_steps, colWidths=[40, 110, 380])
    t_setup.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#CBD5E1")),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_setup)
    story.append(Spacer(1, 14))

    # SECTION 4: MANUAL DESKTOP SHORTCUT CREATION
    story.append(Paragraph("4. Manual Desktop Shortcut Creation (Alternative)", style_h1))
    story.append(Paragraph(
        "If you prefer to create the Windows Desktop shortcut manually:",
        style_body
    ))
    story.append(Paragraph("1. Open the project folder in File Explorer.", style_bullet))
    story.append(Paragraph("2. Right-click on <b><code>Start_Mandi_ERP.bat</code></b>.", style_bullet))
    story.append(Paragraph("3. Select <b>Send to ➔ Desktop (create shortcut)</b>.", style_bullet))
    story.append(Paragraph("4. Go to Desktop, right-click the shortcut, select <b>Rename</b>, and type <b>Mandi ERP</b>.", style_bullet))

    story.append(Spacer(1, 10))

    # SECTION 5: FEATURES SUMMARY & VERIFICATION
    story.append(Paragraph("5. Features Summary for Client Presentation", style_h1))
    
    feats = [
        ("Multi-Tenancy & Shop Profiles", "Supports multiple shops/users with separate login, shop headers, and city credentials."),
        ("Double-Entry Ledger", "Real-time running khata tracking exact debit, credit, opening balance, and live party status (Lena Hai / Dena Hai)."),
        ("Dual Voucher Receipts", "1-Click printable / shareable vouchers for both Kisan Settlement Parchi and Buyer Invoice."),
        ("AI Machine Learning Engine", "Built-in ML price prediction (7-day ahead crop rate forecasting) and Farmer Credit Risk scoring."),
        ("Offline Local Storage", "100% offline database operation - no internet required for daily shop operations.")
    ]

    for title, desc in feats:
        story.append(Paragraph(f"• <b>{title}:</b> {desc}", style_bullet))

    story.append(Spacer(1, 15))
    story.append(HRFlowable(width="100%", thickness=1, color=c_primary, spaceBefore=10, spaceAfter=10))
    story.append(Paragraph("<b>Mandi ERP System v2.0</b> — Designed for High Efficiency Grain Market Operations", ParagraphStyle('FooterText', parent=style_subtitle, fontSize=9, alignment=TA_CENTER)))

    doc.build(story)
    print(f"PDF successfully generated: {filename}")

if __name__ == "__main__":
    build_pdf()
