"""
============================================================
TRADE AND PORTFOLIO PLATFORM
Application 2: Portfolio Analysis
Language: Python 3 with mysql-connector-python
============================================================

Install dependency:
    pip install mysql-connector-python

Usage:
    python portfolio_analysis.py
============================================================
"""

import mysql.connector
from mysql.connector import Error
from decimal import Decimal


# ------------------------------------------------------------
# DATABASE CONNECTION
# ------------------------------------------------------------
def get_connection():
    return mysql.connector.connect(
        host     = 'localhost',
        database = 'tradeplatform',
        user     = 'root',
        password = 'your_password_here' #<-- REPLACE with your MySQL root password
    )


# ------------------------------------------------------------
# HELPER: Pretty print a result set
# ------------------------------------------------------------
def print_table(cursor, title):
    rows = cursor.fetchall()
    cols = [desc[0] for desc in cursor.description]
    
    print(f"\n{'=' * 65}")
    print(f"  {title}")
    print(f"{'=' * 65}")
    
    if not rows:
        print("  No data found.")
        return rows
    
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
    return rows


# ------------------------------------------------------------
# ANALYSIS 1: Full portfolio with unrealised PnL
# ------------------------------------------------------------
def portfolio_summary(cursor, customer_id):
    """
    Show all holdings with current prices and unrealised PnL.
    Joins: investment_account → portfolio_holding → stock → stock_price
    """
    cursor.execute("""
        SELECT
            ia.investment_account_id,
            s.ticker,
            s.company_name,
            ph.quantity,
            ph.avg_buy_price,
            latest.price                                        AS current_price,
            latest.currency_code,
            ROUND(ph.quantity * ph.avg_buy_price, 2)            AS cost_basis,
            ROUND(ph.quantity * latest.price, 2)                AS current_value,
            ROUND((latest.price - ph.avg_buy_price)
                  * ph.quantity, 2)                             AS unrealised_pnl,
            ROUND(((latest.price - ph.avg_buy_price)
                  / ph.avg_buy_price) * 100, 2)                 AS pnl_pct
        FROM investment_account ia
        JOIN portfolio_holding ph  ON ia.investment_account_id = ph.investment_account_id
        JOIN stock s               ON ph.stock_id = s.stock_id
        JOIN (
            SELECT stock_id, price, currency_code
            FROM stock_price sp1
            WHERE as_of_time = (
                SELECT MAX(as_of_time)
                FROM stock_price sp2
                WHERE sp2.stock_id = sp1.stock_id
            )
        ) latest ON s.stock_id = latest.stock_id
        WHERE ia.customer_id = %s
        AND ph.quantity > 0
        ORDER BY unrealised_pnl DESC
    """, (customer_id,))
    
    rows = print_table(cursor, "PORTFOLIO HOLDINGS & UNREALISED PnL")
    return rows


# ------------------------------------------------------------
# ANALYSIS 2: Portfolio totals summary
# ------------------------------------------------------------
def portfolio_totals(cursor, customer_id):
    """
    Aggregate portfolio stats: total invested, current value,
    total unrealised PnL, number of positions.
    Uses GROUP BY and aggregate functions.
    """
    cursor.execute("""
        SELECT
            COUNT(ph.holding_id)                                AS total_positions,
            ROUND(SUM(ph.quantity * ph.avg_buy_price), 2)       AS total_invested,
            ROUND(SUM(ph.quantity * latest.price), 2)           AS current_value,
            ROUND(SUM((latest.price - ph.avg_buy_price)
                  * ph.quantity), 2)                            AS total_unrealised_pnl,
            ROUND((SUM(ph.quantity * latest.price)
                  / SUM(ph.quantity * ph.avg_buy_price) - 1)
                  * 100, 2)                                     AS overall_return_pct
        FROM investment_account ia
        JOIN portfolio_holding ph  ON ia.investment_account_id = ph.investment_account_id
        JOIN (
            SELECT stock_id, price
            FROM stock_price sp1
            WHERE as_of_time = (
                SELECT MAX(as_of_time)
                FROM stock_price sp2
                WHERE sp2.stock_id = sp1.stock_id
            )
        ) latest ON ph.stock_id = latest.stock_id
        WHERE ia.customer_id = %s
        AND ph.quantity > 0
    """, (customer_id,))
    print_table(cursor, "PORTFOLIO SUMMARY TOTALS")


# ------------------------------------------------------------
# ANALYSIS 3: Trade history
# ------------------------------------------------------------
def trade_history(cursor, customer_id):
    """
    Full trade history for a customer across all accounts.
    Joins: investment_account → orders → trade → stock
    """
    cursor.execute("""
        SELECT
            t.trade_id,
            t.trade_time,
            s.ticker,
            t.side,
            t.quantity,
            t.price,
            t.gross_value,
            COALESCE(tc.amount, 0)                              AS brokerage,
            ROUND(t.gross_value + COALESCE(tc.amount, 0), 2)   AS total_cost,
            se.status                                           AS settlement_status
        FROM trade t
        JOIN orders o          ON t.order_id   = o.order_id
        JOIN stock s           ON t.stock_id   = s.stock_id
        LEFT JOIN trade_charge tc  ON t.trade_id = tc.trade_id
        LEFT JOIN settlement se    ON t.trade_id = se.trade_id
        JOIN investment_account ia ON o.investment_account_id
                                   = ia.investment_account_id
        WHERE ia.customer_id = %s
        ORDER BY t.trade_time DESC
    """, (customer_id,))
    print_table(cursor, "TRADE HISTORY")


# ------------------------------------------------------------
# ANALYSIS 4: Pending settlements
# ------------------------------------------------------------
def pending_settlements(cursor, customer_id):
    """
    Show all trades that haven't settled yet (T+2 pending).
    """
    cursor.execute("""
        SELECT
            se.settlement_id,
            s.ticker,
            t.side,
            t.quantity,
            t.gross_value,
            se.scheduled_date,
            se.status,
            se.payment_method
        FROM settlement se
        JOIN trade t           ON se.trade_id  = t.trade_id
        JOIN stock s           ON t.stock_id   = s.stock_id
        JOIN orders o          ON t.order_id   = o.order_id
        JOIN investment_account ia ON o.investment_account_id
                                   = ia.investment_account_id
        WHERE ia.customer_id = %s
        AND se.status = 'PENDING'
        ORDER BY se.scheduled_date
    """, (customer_id,))
    print_table(cursor, "PENDING SETTLEMENTS")


# ------------------------------------------------------------
# ANALYSIS 5: Account balance across all accounts
# ------------------------------------------------------------
def account_balances(cursor, customer_id):
    """
    Show all bank account balances per currency.
    """
    cursor.execute("""
        SELECT
            ba.account_number,
            ba.account_type,
            c.name              AS currency,
            ab.available_balance,
            ab.blocked_balance,
            ab.txn_total_balance
        FROM bank_account ba
        JOIN account_balance ab ON ba.bank_account_id = ab.bank_account_id
        JOIN currency c         ON ab.currency_code   = c.currency_code
        WHERE ba.customer_id = %s
        ORDER BY ba.account_number, ab.currency_code
    """, (customer_id,))
    print_table(cursor, "ACCOUNT BALANCES")


# ------------------------------------------------------------
# ANALYSIS 6: Watchlist with current prices
# ------------------------------------------------------------
def watchlist_with_prices(cursor, customer_id):
    """
    Show all watchlist items with current prices.
    Joins: watchlist → watchlist_item → stock → stock_price
    """
    cursor.execute("""
        SELECT
            w.watchlist_id,
            s.ticker,
            s.company_name,
            latest.price        AS current_price,
            latest.currency_code,
            pa.trigger_price    AS alert_price,
            pa.condition        AS alert_condition
        FROM watchlist w
        JOIN watchlist_item wi ON w.watchlist_id  = wi.watchlist_id
        JOIN stock s           ON wi.stock_id     = s.stock_id
        JOIN (
            SELECT stock_id, price, currency_code
            FROM stock_price sp1
            WHERE as_of_time = (
                SELECT MAX(as_of_time)
                FROM stock_price sp2
                WHERE sp2.stock_id = sp1.stock_id
            )
        ) latest ON s.stock_id = latest.stock_id
        LEFT JOIN price_alert pa ON pa.stock_id    = s.stock_id
                                AND pa.customer_id = w.customer_id
                                AND pa.is_active   = 1
        WHERE w.customer_id = %s
        ORDER BY w.watchlist_id, s.ticker
    """, (customer_id,))
    print_table(cursor, "WATCHLIST WITH CURRENT PRICES & ALERTS")


# ------------------------------------------------------------
# ANALYSIS 7: Daily trading activity
# ------------------------------------------------------------
def daily_activity(cursor, customer_id):
    """
    Show trading activity summary for each day.
    Useful for both customer self-review and admin monitoring.
    """
    cursor.execute("""
        SELECT
            dlu.usage_date,
            dlu.trades_count,
            dlu.trades_value,
            dlu.gross_traded_value,
            dlu.risk_level,
            rp.max_order_value          AS max_per_order_allowed
        FROM daily_limit_usage dlu
        JOIN risk_profile rp ON dlu.customer_id = rp.customer_id
        WHERE dlu.customer_id = %s
        ORDER BY dlu.usage_date DESC
        LIMIT 30
    """, (customer_id,))
    print_table(cursor, "DAILY TRADING ACTIVITY (Last 30 days)")


# ------------------------------------------------------------
# ANALYSIS 8: Fee summary across all trades
# ------------------------------------------------------------
def fee_summary(cursor, customer_id):
    """
    Show total fees paid per fee type across all trades.
    Uses GROUP BY and SUM aggregation.
    """
    cursor.execute("""
        SELECT
            tc.free_type            AS fee_type,
            COUNT(tc.trade_charge_id) AS num_charges,
            ROUND(SUM(tc.amount), 2)  AS total_fees_paid,
            ROUND(AVG(tc.amount), 2)  AS avg_fee_per_trade,
            ROUND(MIN(tc.amount), 2)  AS min_fee,
            ROUND(MAX(tc.amount), 2)  AS max_fee
        FROM trade_charge tc
        JOIN trade t           ON tc.trade_id  = t.trade_id
        JOIN orders o          ON t.order_id   = o.order_id
        JOIN investment_account ia ON o.investment_account_id
                                   = ia.investment_account_id
        WHERE ia.customer_id = %s
        GROUP BY tc.free_type
        ORDER BY total_fees_paid DESC
    """, (customer_id,))
    print_table(cursor, "FEE SUMMARY (All Time)")


# ------------------------------------------------------------
# ANALYSIS 9: Stock performance comparison
#             (stocks in portfolio vs their purchase price)
# ------------------------------------------------------------
def stock_performance_comparison(cursor, customer_id):
    """
    Compare each held stock's performance:
    - Price when first bought (oldest holding lot)
    - Current price
    - Total return since first purchase
    """
    cursor.execute("""
        SELECT
            s.ticker,
            s.company_name,
            MIN(t.price)                                        AS first_buy_price,
            latest.price                                        AS current_price,
            ROUND(((latest.price - MIN(t.price))
                  / MIN(t.price)) * 100, 2)                    AS total_return_pct,
            ph.quantity                                         AS shares_held
        FROM portfolio_holding ph
        JOIN investment_account ia ON ph.investment_account_id
                                   = ia.investment_account_id
        JOIN stock s               ON ph.stock_id = s.stock_id
        JOIN orders o              ON ia.investment_account_id
                                   = o.investment_account_id
                                AND o.stock_id = ph.stock_id
                                AND o.side = 'BUY'
        JOIN trade t               ON o.order_id = t.order_id
        JOIN (
            SELECT stock_id, price
            FROM stock_price sp1
            WHERE as_of_time = (
                SELECT MAX(as_of_time)
                FROM stock_price sp2
                WHERE sp2.stock_id = sp1.stock_id
            )
        ) latest ON s.stock_id = latest.stock_id
        WHERE ia.customer_id = %s
        AND ph.quantity > 0
        GROUP BY s.ticker, s.company_name, latest.price, ph.quantity
        ORDER BY total_return_pct DESC
    """, (customer_id,))
    print_table(cursor, "STOCK PERFORMANCE COMPARISON")


# ------------------------------------------------------------
# ADMIN VIEW: Top traders by gross value today
# ------------------------------------------------------------
def admin_top_traders(cursor):
    """
    Admin query: which customers have traded the most today?
    Shows daily_limit_usage for CURDATE() ordered by volume.
    """
    cursor.execute("""
        SELECT
            c.customer_id,
            c.name,
            rp.profile_name         AS risk_profile,
            dlu.trades_count,
            dlu.gross_traded_value,
            dlu.risk_level
        FROM daily_limit_usage dlu
        JOIN customer c    ON dlu.customer_id = c.customer_id
        JOIN risk_profile rp ON c.customer_id = rp.customer_id
        WHERE dlu.usage_date = CURDATE()
        ORDER BY dlu.gross_traded_value DESC
    """)
    print_table(cursor, "ADMIN: TOP TRADERS TODAY")


# ------------------------------------------------------------
# MAIN: Run full portfolio analysis for a customer
# ------------------------------------------------------------
def main():
    print("\n" + "=" * 65)
    print("  TRADE AND PORTFOLIO PLATFORM")
    print("  Application: Portfolio Analysis")
    print("=" * 65)
    
    conn   = None
    cursor = None
    
    try:
        conn   = get_connection()
        cursor = conn.cursor()
        
        CUSTOMER_ID = 1  # Alice Johnson
        
        print(f"\n  Running full portfolio analysis for Customer ID: {CUSTOMER_ID}")
        print(f"  (Alice Johnson)")
        
        # 1. Portfolio holdings with PnL
        portfolio_summary(cursor, CUSTOMER_ID)
        
        # 2. Portfolio totals
        portfolio_totals(cursor, CUSTOMER_ID)
        
        # 3. Trade history
        trade_history(cursor, CUSTOMER_ID)
        
        # 4. Pending settlements
        pending_settlements(cursor, CUSTOMER_ID)
        
        # 5. Account balances
        account_balances(cursor, CUSTOMER_ID)
        
        # 6. Watchlist
        watchlist_with_prices(cursor, CUSTOMER_ID)
        
        # 7. Daily activity
        daily_activity(cursor, CUSTOMER_ID)
        
        # 8. Fee summary
        fee_summary(cursor, CUSTOMER_ID)
        
        # 9. Stock performance
        stock_performance_comparison(cursor, CUSTOMER_ID)
        
        # 10. Admin view
        admin_top_traders(cursor)
        
        print("\n  Portfolio analysis complete.")
    
    except Exception as e:
        print(f"\n  ERROR: {e}")
    
    finally:
        if cursor: cursor.close()
        if conn:   conn.close()
        print("  Connection closed.\n")


if __name__ == '__main__':
    main()