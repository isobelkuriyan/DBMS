"""
============================================================
TRADE AND PORTFOLIO PLATFORM
Application 1: Place a Trade (Equity Order)
Language: Python 3 with mysql-connector-python
============================================================

Install dependency:
    pip install mysql-connector-python

Usage:
    python place_trade.py
============================================================
"""

import mysql.connector
from mysql.connector import Error
import uuid


# ------------------------------------------------------------
# DATABASE CONNECTION
# ------------------------------------------------------------
def get_connection():
    """Create and return a database connection."""
    return mysql.connector.connect(
        host       = 'localhost',
        database   = 'tradeplatformm',
        user       = 'root',
        password   = 'Opbaco9916?', #<-- REPLACE with your MySQL root password
        autocommit = False
    )


# ------------------------------------------------------------
# HELPER: Pretty print a result set
# ------------------------------------------------------------
def print_table(cursor, title):
    rows = cursor.fetchall()
    cols = [desc[0] for desc in cursor.description]

    print(f"\n{'=' * 70}")
    print(f"  {title}")
    print(f"{'=' * 70}")

    if not rows:
        print("  No results found.")
        return

    widths = [len(c) for c in cols]
    for row in rows:
        for i, val in enumerate(row):
            widths[i] = max(widths[i], len(str(val) if val is not None else 'NULL'))

    header = '  ' + ' | '.join(c.ljust(widths[i]) for i, c in enumerate(cols))
    print(header)
    print('  ' + '-' * (len(header) - 2))

    for row in rows:
        line = '  ' + ' | '.join(
            (str(v) if v is not None else 'NULL').ljust(widths[i])
            for i, v in enumerate(row)
        )
        print(line)
    print()


# ------------------------------------------------------------
# STEP 1: Authenticate customer
# ------------------------------------------------------------
def authenticate_customer(cursor, customer_id):
    cursor.execute("""
        SELECT customer_id, name, email, kyc_status
        FROM customer WHERE customer_id = %s
    """, (customer_id,))
    customer = cursor.fetchone()
    if not customer:
        raise Exception(f"Customer ID {customer_id} not found.")
    if customer[3] != 'VERIFIED':
        raise Exception(f"Customer not KYC verified. Status: {customer[3]}")
    print(f"\n  Customer authenticated: {customer[1]} (ID: {customer[0]})")
    return customer


# ------------------------------------------------------------
# STEP 2: Show available stocks
# ------------------------------------------------------------
def show_available_stocks(cursor):
    cursor.execute("""
        SELECT s.stock_id, s.ticker, s.company_name, s.exchange,
               latest.price AS current_price, latest.currency_code
        FROM stock s
        JOIN (
            SELECT stock_id, price, currency_code
            FROM stock_price sp1
            WHERE as_of_time = (
                SELECT MAX(as_of_time) FROM stock_price sp2
                WHERE sp2.stock_id = sp1.stock_id
            )
        ) latest ON s.stock_id = latest.stock_id
        WHERE s.is_active = 1
        ORDER BY s.ticker
    """)
    print_table(cursor, "AVAILABLE STOCKS")


# ------------------------------------------------------------
# STEP 3: Show investment accounts
# ------------------------------------------------------------
def get_investment_accounts(cursor, customer_id):
    cursor.execute("""
        SELECT investment_account_id, broker_number, status, opened_at
        FROM investment_account
        WHERE customer_id = %s AND status = 'ACTIVE'
    """, (customer_id,))
    accounts = cursor.fetchall()
    if not accounts:
        raise Exception("No active investment accounts found.")
    print(f"\n{'=' * 70}")
    print("  YOUR INVESTMENT ACCOUNTS")
    print(f"{'=' * 70}")
    for acc in accounts:
        print(f"  ID: {acc[0]}  |  Broker#: {acc[1]}  |  Status: {acc[2]}")
    return accounts


# ------------------------------------------------------------
# STEP 4: Show account balance
# ------------------------------------------------------------
def show_balance(cursor, customer_id, label="ACCOUNT BALANCE"):
    cursor.execute("""
        SELECT ba.account_number, c.name AS currency,
               ab.available_balance, ab.blocked_balance, ab.txn_total_balance
        FROM bank_account ba
        JOIN account_balance ab ON ba.bank_account_id = ab.bank_account_id
        JOIN currency c         ON ab.currency_code   = c.currency_code
        WHERE ba.customer_id = %s
        ORDER BY ba.account_number, ab.currency_code
    """, (customer_id,))
    print_table(cursor, label)


# ------------------------------------------------------------
# STEP 5: Show portfolio holdings
# ------------------------------------------------------------
def show_portfolio(cursor, investment_account_id, label="PORTFOLIO HOLDINGS"):
    cursor.execute("""
        SELECT s.ticker, s.company_name, ph.quantity,
               ph.avg_buy_price, latest.price AS current_price,
               ROUND((latest.price - ph.avg_buy_price) * ph.quantity, 2) AS unrealised_pnl
        FROM portfolio_holding ph
        JOIN stock s ON ph.stock_id = s.stock_id
        JOIN (
            SELECT stock_id, price FROM stock_price sp1
            WHERE as_of_time = (
                SELECT MAX(as_of_time) FROM stock_price sp2
                WHERE sp2.stock_id = sp1.stock_id
            )
        ) latest ON s.stock_id = latest.stock_id
        WHERE ph.investment_account_id = %s AND ph.quantity > 0
        ORDER BY s.ticker
    """, (investment_account_id,))
    print_table(cursor, label)


# ------------------------------------------------------------
# STEP 6: Show holding lots
# ------------------------------------------------------------
def show_holding_lots(cursor, investment_account_id, label="HOLDING LOTS"):
    cursor.execute("""
        SELECT hl.lot_id, s.ticker, t.side,
               t.quantity AS lot_quantity, t.price AS purchase_price,
               t.gross_value, t.trade_time AS purchased_on,
               hl.status AS lot_status, se.status AS settlement_status
        FROM holding_lot hl
        JOIN settlement se ON hl.settlement_id = se.settlement_id
        JOIN trade t       ON se.trade_id       = t.trade_id
        JOIN stock s       ON hl.stock_id       = s.stock_id
        WHERE hl.investment_account_id = %s
        ORDER BY s.ticker, t.trade_time
    """, (investment_account_id,))
    print_table(cursor, label)


# ------------------------------------------------------------
# STEP 7: Show daily limit usage
# ------------------------------------------------------------
def show_daily_limit_usage(cursor, customer_id, label="DAILY LIMIT USAGE"):
    cursor.execute("""
        SELECT dlu.usage_date, dlu.trades_count,
               dlu.trades_value, dlu.gross_traded_value,
               rp.max_order_value AS max_per_order
        FROM daily_limit_usage dlu
        JOIN risk_profile rp ON dlu.customer_id = rp.customer_id
        WHERE dlu.customer_id = %s AND dlu.usage_date = CURDATE()
    """, (customer_id,))
    print_table(cursor, label)


# ------------------------------------------------------------
# STEP 8: Check risk profile
# ------------------------------------------------------------
def check_risk_profile(cursor, customer_id, order_value):
    cursor.execute("""
        SELECT profile_name, max_order_value
        FROM risk_profile WHERE customer_id = %s
    """, (customer_id,))
    profile = cursor.fetchone()
    if not profile:
        print("  No risk profile found. Proceeding.")
        return
    print(f"\n  Risk Profile : {profile[0]}")
    print(f"  Max Order    : {profile[1]}")
    print(f"  This Order   : {order_value}")
    if profile[1] and order_value > float(profile[1]):
        raise Exception(f"Order value exceeds risk limit of {profile[1]}")
    print("  Risk check passed.")


# ------------------------------------------------------------
# STEP 9: Place order + execute trade (atomic transaction)
# ------------------------------------------------------------
def place_order_and_trade(
    conn, cursor,
    investment_account_id, stock_id, order_type,
    quantity, limit_price, side, currency_code, customer_id,
    payment_method='BANK', card_id=None
):
    """
    Full atomic trade execution.

    Inserts: orders → order_fill → trade → trade_charge
             → bank_txn → settlement → trade_payment → holding_lot

    Triggers fired automatically:
      BEFORE INSERT orders:
        trg_check_order_risk                  (risk limit)
        trg_check_funds_before_order          (balance/card check)
        trg_check_shares_before_sell          (sell qty check)
        trg_check_account_status_before_order (suspended check)
        trg_check_stock_active_before_order   (delisted check)
      AFTER INSERT trade:
        trg_update_portfolio_after_trade      (portfolio_holding)
        trg_update_daily_limit_after_trade    (daily_limit_usage)
      BEFORE INSERT bank_txn:
        trg_check_balance_before_txn          (overdraft guard)
      AFTER INSERT bank_txn:
        trg_update_balance_after_txn          (account_balance)
    """
    order_ref_id = f"ORD-{uuid.uuid4().hex[:8].upper()}"
    gross_value  = round(float(quantity) * float(limit_price or 0), 4)

    try:
        print(f"\n  Starting transaction for {side} {quantity} shares...")

        # INSERT ORDER (BEFORE triggers fire here)
        cursor.execute("""
            INSERT INTO orders (
                order_ref_id, investment_account_id, stock_id,
                order_type, quantity, limit_price, side,
                currency_code, payment_method, card_id,
                reserved_amount, status
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'FILLED')
        """, (
            order_ref_id, investment_account_id, stock_id,
            order_type, quantity, limit_price, side,
            currency_code, payment_method, card_id, gross_value
        ))
        order_id = cursor.lastrowid
        print(f"  Order inserted          : ID={order_id}, Ref={order_ref_id}")

        # INSERT ORDER FILL
        cursor.execute("""
            INSERT INTO order_fill (order_id, filled_qty, fill_price, currency_code)
            VALUES (%s, %s, %s, %s)
        """, (order_id, quantity, limit_price, currency_code))
        fill_id = cursor.lastrowid
        print(f"  Order fill inserted     : ID={fill_id}")

        # INSERT TRADE
        # >> Trigger 4: trg_update_portfolio_after_trade fires here
        # >> Trigger 5: trg_update_daily_limit_after_trade fires here
        cursor.execute("""
            INSERT INTO trade (
                fill_id, order_id, stock_id, side,
                quantity, price, currency_code, gross_value
            ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        """, (fill_id, order_id, stock_id, side,
              quantity, limit_price, currency_code, gross_value))
        trade_id = cursor.lastrowid
        print(f"  Trade executed          : ID={trade_id}, Gross={gross_value}")
        print(f"  >> Trigger 4 fired      : portfolio_holding updated automatically")
        print(f"  >> Trigger 5 fired      : daily_limit_usage updated automatically")

        # INSERT TRADE CHARGE (brokerage fee)
        cursor.execute("""
            SELECT rate, min_fee, max_fee FROM fee_rule
            WHERE investment_account_id = %s
            AND fee_type = 'BROKERAGE' AND is_active = 1 LIMIT 1
        """, (investment_account_id,))
        fee_row = cursor.fetchone()

        charge = 0.0
        if fee_row:
            rate, min_fee, max_fee = fee_row
            charge = gross_value * float(rate)
            charge = max(charge, float(min_fee or 0))
            if max_fee:
                charge = min(charge, float(max_fee))
            charge = round(charge, 2)
            cursor.execute("""
                INSERT INTO trade_charge (trade_id, free_type, amount)
                VALUES (%s, 'BROKERAGE', %s)
            """, (trade_id, charge))
            print(f"  Trade charge inserted   : Brokerage = {charge}")

        # INSERT BANK TXN
        # >> Trigger 7: trg_check_balance_before_txn fires (overdraft guard)
        # >> Trigger 6: trg_update_balance_after_txn fires (balance update)
        # After inserting the order, read back what Trigger 2 decided
        cursor.execute("""
            SELECT reserved_amount, chosen_bank_account_id
            FROM orders WHERE order_id = %s
        """, (order_id,))
        trigger_row = cursor.fetchone()

        if trigger_row and payment_method == 'BANK':
            debit_amount    = float(trigger_row[0])  # already FX-converted + markup
            bank_account_id = trigger_row[1]         # account Trigger 2 chose

            # Get the currency of that bank account (for the bank_txn insert)
            cursor.execute("""
                SELECT ab.currency_code
                FROM account_balance ab
                WHERE ab.bank_account_id = %s
                ORDER BY ab.available_balance DESC LIMIT 1
            """, (bank_account_id,))
            debit_currency = cursor.fetchone()[0]  # EUR, GBP, INR, or USD

            if side == 'BUY':
                total_debit = round(debit_amount + charge, 2)
                cursor.execute("""
                    INSERT INTO bank_txn (
                        bank_account_id, txn_type, direction,
                        amount, currency_code, description,
                        reference_type, reference_id
                    ) VALUES (%s,'DEBIT','OUT',%s,%s,%s,'TRADE',%s)
                """, (
                    bank_account_id, total_debit, debit_currency,
                    f"BUY {quantity} shares stock_id={stock_id} + brokerage (FX applied)",
                    trade_id
                ))
            else:
                net_credit = round(gross_value - charge, 2)
                cursor.execute("""
                    INSERT INTO bank_txn (
                        bank_account_id, txn_type, direction,
                        amount, currency_code, description,
                        reference_type, reference_id
                    ) VALUES (%s,'CREDIT','IN',%s,%s,%s,'TRADE',%s)
                """, (
                    bank_account_id, net_credit, currency_code,
                    f"SELL {quantity} shares stock_id={stock_id} minus brokerage",
                    trade_id
                ))
                print(f"  Bank txn inserted       : CREDIT {net_credit} {currency_code}")
            print(f"  >> Trigger 7 fired      : overdraft check passed")
            print(f"  >> Trigger 6 fired      : account_balance updated automatically")

        # INSERT SETTLEMENT (T+2)
        cursor.execute("""
            INSERT INTO settlement (
                trade_id, investment_account_id, currency_code,
                scheduled_date, status, payment_method
            ) VALUES (%s,%s,%s, DATE_ADD(CURDATE(), INTERVAL 2 DAY), 'PENDING',%s)
        """, (trade_id, investment_account_id, currency_code, payment_method))
        settlement_id = cursor.lastrowid
        print(f"  Settlement inserted     : ID={settlement_id}, scheduled T+2")

        # INSERT TRADE PAYMENT
        cursor.execute("""
            INSERT INTO trade_payment (order_id, trade_id, buy_trade_id, status, payment_method)
            VALUES (%s,%s,%s,'PENDING',%s)
        """, (order_id, trade_id, trade_id if side == 'BUY' else None, payment_method))
        print(f"  Trade payment inserted  : PENDING")

        # INSERT HOLDING LOT (tax lot tracking)
        cursor.execute("""
            INSERT INTO holding_lot (settlement_id, investment_account_id, stock_id, status)
            VALUES (%s,%s,%s,'OPEN')
        """, (settlement_id, investment_account_id, stock_id))
        print(f"  Holding lot inserted    : lot for settlement {settlement_id}")

        conn.commit()
        print(f"\n  Transaction COMMITTED successfully.")
        return order_id, trade_id

    except Error as e:
        conn.rollback()
        print(f"\n  Transaction ROLLED BACK.")
        raise Exception(f"Database error: {e}")
    except Exception as e:
        conn.rollback()
        print(f"\n  Transaction ROLLED BACK.")
        raise


# ------------------------------------------------------------
# STEP 10: Show trade confirmation
# ------------------------------------------------------------
def show_trade_confirmation(cursor, trade_id):
    cursor.execute("""
        SELECT t.trade_id, s.company_name, s.ticker, t.side,
               t.quantity, t.price, t.gross_value,
               COALESCE(tc.amount, 0) AS brokerage_fee,
               ROUND(t.gross_value + COALESCE(tc.amount, 0), 2) AS total_cost,
               t.trade_time,
               se.scheduled_date AS settlement_date,
               se.status         AS settlement_status
        FROM trade t
        JOIN stock s              ON t.stock_id = s.stock_id
        LEFT JOIN trade_charge tc ON t.trade_id = tc.trade_id
        LEFT JOIN settlement se   ON t.trade_id = se.trade_id
        WHERE t.trade_id = %s
    """, (trade_id,))
    print_table(cursor, "TRADE CONFIRMATION")


# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------
def main():
    print("\n" + "=" * 70)
    print("  TRADE AND PORTFOLIO PLATFORM")
    print("  Application: Place a Trade")
    print("=" * 70)

    conn = cursor = None

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        CUSTOMER_ID           = 1
        INVESTMENT_ACCOUNT_ID = 1
        STOCK_ID              = 3       # GOOGL
        ORDER_TYPE            = 'LIMIT'
        QUANTITY              = 5.0
        LIMIT_PRICE           = 153.40
        SIDE                  = 'BUY'
        CURRENCY              = 'USD'
        PAYMENT_METHOD        = 'BANK'
        CARD_ID               = None
        ORDER_VALUE           = QUANTITY * LIMIT_PRICE

        # Authenticate
        authenticate_customer(cursor, CUSTOMER_ID)

        # Show stocks
        show_available_stocks(cursor)

        # Show accounts
        get_investment_accounts(cursor, CUSTOMER_ID)

        # Risk check
        check_risk_profile(cursor, CUSTOMER_ID, ORDER_VALUE)

        # ------------------------------------------------
        # SNAPSHOT BEFORE TRADE
        # ------------------------------------------------
        print("\n" + "=" * 70)
        print("  *** SNAPSHOT BEFORE TRADE ***")
        print("=" * 70)
        show_portfolio(cursor, INVESTMENT_ACCOUNT_ID,
                       label="PORTFOLIO BEFORE TRADE")
        show_holding_lots(cursor, INVESTMENT_ACCOUNT_ID,
                          label="HOLDING LOTS BEFORE TRADE")
        show_balance(cursor, CUSTOMER_ID,
                     label="ACCOUNT BALANCE BEFORE TRADE")
        show_daily_limit_usage(cursor, CUSTOMER_ID,
                               label="DAILY LIMIT USAGE BEFORE TRADE")

        # ------------------------------------------------
        # PLACE TRADE
        # ------------------------------------------------
        print(f"\n  Placing {SIDE} order:")
        print(f"    Stock          : {STOCK_ID} (GOOGL)")
        print(f"    Quantity       : {QUANTITY}")
        print(f"    Price          : {LIMIT_PRICE}")
        print(f"    Total          : {ORDER_VALUE}")
        print(f"    Payment method : {PAYMENT_METHOD}")

        order_id, trade_id = place_order_and_trade(
            conn, cursor,
            INVESTMENT_ACCOUNT_ID, STOCK_ID, ORDER_TYPE,
            QUANTITY, LIMIT_PRICE, SIDE, CURRENCY, CUSTOMER_ID,
            PAYMENT_METHOD, CARD_ID
        )

        show_trade_confirmation(cursor, trade_id)

        # ------------------------------------------------
        # SNAPSHOT AFTER TRADE
        # ------------------------------------------------
        print("\n" + "=" * 70)
        print("  *** SNAPSHOT AFTER TRADE ***")
        print("=" * 70)

        show_portfolio(cursor, INVESTMENT_ACCOUNT_ID,
                       label="PORTFOLIO AFTER TRADE  [Trigger 4 updated this]")
        show_holding_lots(cursor, INVESTMENT_ACCOUNT_ID,
                          label="HOLDING LOTS AFTER TRADE  [new lot added in transaction]")
        show_balance(cursor, CUSTOMER_ID,
                     label="ACCOUNT BALANCE AFTER TRADE  [Trigger 6 updated this]")
        show_daily_limit_usage(cursor, CUSTOMER_ID,
                               label="DAILY LIMIT USAGE AFTER TRADE  [Trigger 5 updated this]")

        print("\n  Trade placed successfully.")

        # ------------------------------------------------
        # TRIGGER ENFORCEMENT DEMO
        # ------------------------------------------------
        print("\n" + "=" * 70)
        print("  DEMONSTRATING TRIGGER ENFORCEMENT")
        print("=" * 70)

        tests = [
            ("Order exceeding risk limit (1000 NVDA = 875,000 > 500,000)",
             9, 'LIMIT', 1000.0, 875.00, 'BUY'),
            ("Insufficient balance (9999 AAPL shares)",
             1, 'LIMIT', 9999.0, 184.20, 'BUY'),
            ("Selling more shares than owned (999 AAPL, owns ~55)",
             1, 'LIMIT', 999.0, 184.20, 'SELL'),
            ("Trading a delisted stock (Boeing BA, is_active=0)",
             15, 'MARKET', 10.0, 220.00, 'BUY'),
        ]

        for i, (desc, sid, otype, qty, price, side) in enumerate(tests, 1):
            print(f"\n  [{i}] {desc}")
            try:
                place_order_and_trade(
                    conn, cursor,
                    INVESTMENT_ACCOUNT_ID, sid, otype,
                    qty, price, side, CURRENCY, CUSTOMER_ID,
                    'BANK', None
                )
            except Exception as e:
                print(f"  Trigger blocked: {e}")

    except Exception as e:
        print(f"\n  ERROR: {e}")

    finally:
        if cursor: cursor.close()
        if conn:   conn.close()
        print("\n  Connection closed.")


if __name__ == '__main__':
    main()