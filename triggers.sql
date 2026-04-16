-- ============================================================
-- TRADE AND PORTFOLIO PLATFORM -- TRIGGERS
-- MySQL 8.0+
-- ============================================================

-- ============================================================
-- TRIGGER 1: Block order if it exceeds risk profile limit
-- Fires: BEFORE INSERT on orders
-- Why: Enforces max_order_value from risk_profile at DB level.
--      No application bug can bypass this.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_check_order_risk
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE max_val     DECIMAL(18,4);
    DECLARE v_customer  INT;
    DECLARE order_val   DECIMAL(18,4);

    -- Derive customer from investment account
    SELECT ia.customer_id INTO v_customer
    FROM investment_account ia
    WHERE ia.investment_account_id = NEW.investment_account_id;

    -- Get their max allowed order value
    SELECT rp.max_order_value INTO max_val
    FROM risk_profile rp
    WHERE rp.customer_id = v_customer;

    -- Calculate this order's value
    SET order_val = NEW.quantity * COALESCE(NEW.limit_price, 0);

    IF max_val IS NOT NULL AND order_val > max_val THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order value exceeds maximum allowed by risk profile';
    END IF;
END$$
DELIMITER ;




-- ============================================================
-- TRIGGER 2 (REWRITTEN): FX-aware balance + funds check
-- Fires: BEFORE INSERT on orders
--
-- What changed vs old version:
--   OLD: checked balance only in the exact currency of the order
--   NEW: detects stock currency vs customer's bank currency,
--        fetches rate + markup from exchange_rate,
--        computes the real EUR/GBP/INR amount needed,
--        checks THAT against available_balance,
--        writes chosen_bank_account_id + reserved_amount back
--        into the order row so Python doesn't have to guess.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_check_funds_before_order
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE v_customer           INT;
    DECLARE v_order_val          DECIMAL(18,4);
    DECLARE v_stock_currency     VARCHAR(10);
    DECLARE v_bank_account_id    INT;
    DECLARE v_bank_currency      VARCHAR(10);
    DECLARE v_available          DECIMAL(18,4);
    DECLARE v_ex_rate            DECIMAL(18,6);
    DECLARE v_markup             DECIMAL(10,6);
    DECLARE v_converted_amount   DECIMAL(18,4);
    DECLARE v_card_limit         DECIMAL(18,4);
    DECLARE v_card_used          DECIMAL(18,4);
    DECLARE v_is_active TINYINT;

    SET v_order_val = NEW.quantity * COALESCE(NEW.limit_price, 0);

    IF NEW.side = 'BUY' AND v_order_val > 0 THEN

        -- Get customer from investment account
        SELECT ia.customer_id INTO v_customer
        FROM investment_account ia
        WHERE ia.investment_account_id = NEW.investment_account_id;

        -- ── BANK payment path 
        IF NEW.payment_method = 'BANK' THEN
			

			SELECT is_active INTO v_is_active
			FROM stock
			WHERE stock_id = NEW.stock_id;

			IF v_is_active = 0 THEN
				SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Cannot place order on a delisted or inactive stock';
			END IF;

            -- Step 1: What currency does the stock trade in?
            SELECT sp.currency_code INTO v_stock_currency
            FROM stock_price sp
            WHERE sp.stock_id = NEW.stock_id
            ORDER BY sp.as_of_time DESC
            LIMIT 1;

            -- Step 2: Find the customer's bank account with
            --         the highest available balance (any currency)
            SELECT ba.bank_account_id,
                   ab.currency_code,
                   ab.available_balance
            INTO   v_bank_account_id,
                   v_bank_currency,
                   v_available
            FROM bank_account ba
            JOIN account_balance ab 
                ON ba.bank_account_id = ab.bank_account_id
            WHERE ba.customer_id = v_customer
            AND   ba.status      = 'ACTIVE'
            ORDER BY ab.available_balance DESC
            LIMIT 1;

            -- Step 3: Fetch exchange rate + bank markup
            --         (same-currency rows: rate=1, markup=0, math still works)
            SELECT rate, bank_fx_markup_percent
            INTO   v_ex_rate, v_markup
            FROM exchange_rate
            WHERE base_currency  = v_stock_currency COLLATE utf8mb4_unicode_ci
            AND   quote_currency = v_bank_currency COLLATE utf8mb4_unicode_ci;

            IF v_ex_rate IS NULL THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 
                    'No exchange rate found for this currency pair. Contact support.';
            END IF;

            -- Step 4: Convert order value into customer's currency
            --   formula: order_val_in_stock_ccy / rate * (1 + markup)
            --   e.g. $767 USD, rate=1.086 (1 EUR = 1.086 USD)
            --        => 767 / 1.086 = €706.45 EUR
            --        => 706.45 * 1.01 = €713.51 EUR (with 1% bank markup)
            SET v_converted_amount = ROUND(
                v_order_val / v_ex_rate * (1 + v_markup),
                4
            );

            -- Step 5: Check against actual available balance
            IF v_available IS NULL OR v_available < v_converted_amount THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 
                    'Insufficient balance (after FX conversion) to place this order';
            END IF;

            -- Step 6: Write results back into the order row
            --         Python reads these — no manual calculation needed
            SET NEW.reserved_amount        = v_converted_amount;
            SET NEW.chosen_bank_account_id = v_bank_account_id;

        -- ── CARD payment path (unchanged) ──────────────────
        ELSEIF NEW.payment_method = 'CARD' THEN

            IF NEW.card_id IS NULL THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 
                    'card_id must be provided when payment_method is CARD';
            END IF;

            SELECT available_limit, used_amount
            INTO   v_card_limit, v_card_used
            FROM credit_card_details
            WHERE card_id = NEW.card_id
            ORDER BY credit_card_id DESC
            LIMIT 1;

            IF v_card_limit IS NULL THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No credit card details found for this card';
            END IF;

            IF (v_card_limit - v_card_used) < v_order_val THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 
                    'Insufficient card credit limit to place this order';
            END IF;

        END IF;

    END IF;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER 3: Block sell order if insufficient shares available
-- Fires: BEFORE INSERT on orders
-- Why: Prevents overselling. Checks quantity - blocked_quantity
--      because some shares may be reserved for pending sells.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_check_shares_before_sell
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE v_available_qty DECIMAL(18,6);

    IF NEW.side = 'SELL' THEN
        SELECT (quantity - blocked_quantity) INTO v_available_qty
        FROM portfolio_holding
        WHERE investment_account_id = NEW.investment_account_id
        AND stock_id = NEW.stock_id;

        IF v_available_qty IS NULL OR v_available_qty < NEW.quantity THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient shares available to place sell order';
        END IF;
    END IF;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER 4: UPDATED
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_update_portfolio_after_trade
AFTER INSERT ON trade
FOR EACH ROW
BEGIN
    DECLARE v_inv_acct_id   INT;
    DECLARE v_existing_qty  DECIMAL(18,6) DEFAULT 0;
    DECLARE v_existing_avg  DECIMAL(18,6) DEFAULT 0;
    DECLARE v_new_avg       DECIMAL(18,6);
    DECLARE v_exists        INT DEFAULT 0;
 
    -- ── Resolve investment account from the originating order ──
    SELECT investment_account_id INTO v_inv_acct_id
    FROM orders
    WHERE order_id = NEW.order_id;
 
    -- ── Check whether a holding row already exists ──────────
    SELECT COUNT(*) INTO v_exists
    FROM portfolio_holding
    WHERE investment_account_id = v_inv_acct_id
      AND stock_id               = NEW.stock_id;
 
    IF v_exists > 0 THEN
        SELECT quantity, avg_buy_price
        INTO   v_existing_qty, v_existing_avg
        FROM portfolio_holding
        WHERE investment_account_id = v_inv_acct_id
          AND stock_id               = NEW.stock_id;
    END IF;
 
    -- ════════════════════════════════════════════════════════
    -- BUY path
    -- ════════════════════════════════════════════════════════
    IF NEW.side = 'BUY' THEN
 
        IF v_exists = 0 THEN
            -- First purchase: create the holding row
            INSERT INTO portfolio_holding
                (investment_account_id, stock_id, quantity, avg_buy_price)
            VALUES
                (v_inv_acct_id, NEW.stock_id, NEW.quantity, NEW.price);
        ELSE
            -- Already holds stock: recalculate weighted average cost
            SET v_new_avg = ((v_existing_qty * v_existing_avg)
                           + (NEW.quantity   * NEW.price))
                           / (v_existing_qty + NEW.quantity);
 
            UPDATE portfolio_holding
            SET quantity      = quantity + NEW.quantity,
                avg_buy_price = v_new_avg,
                last_updated  = NOW()
            WHERE investment_account_id = v_inv_acct_id
              AND stock_id               = NEW.stock_id;
        END IF;
 
        -- ── Open a new tax lot for this BUY ─────────────────
        -- Linked to the settlement created for this trade.
        -- We look up the settlement_id that was created for
        -- this trade by place_trade.py / the settlement insert.
        INSERT INTO holding_lot
            (settlement_id,
             investment_account_id,
             stock_id,
             status,
             quantity,
             remaining_qty,
             buy_price,
             acquired_at)
        SELECT
            se.settlement_id,   -- FK to settlement
            v_inv_acct_id,
            NEW.stock_id,
            'OPEN',
            NEW.quantity,       -- original lot size
            NEW.quantity,       -- fully open at creation
            NEW.price,          -- cost basis per share
            NEW.trade_time
        FROM settlement se
        WHERE se.trade_id = NEW.trade_id
        LIMIT 1;
 
    -- ════════════════════════════════════════════════════════
    -- SELL path
    -- ════════════════════════════════════════════════════════
    ELSEIF NEW.side = 'SELL' THEN
 
        -- ── 1. Reduce aggregate holding (existing behaviour) ─
        UPDATE portfolio_holding
        SET quantity     = quantity - NEW.quantity,
            last_updated = NOW()
        WHERE investment_account_id = v_inv_acct_id
          AND stock_id               = NEW.stock_id;
 
        -- ── 2. FIFO lot-closing ──────────────────────────────
        -- Handled by the dedicated trigger below
        -- (trg_close_lots_fifo_after_sell).
        -- Splitting into a second trigger keeps each trigger
        -- focused on a single responsibility and avoids MySQL's
        -- restriction on recursive trigger depth.
 
    END IF;
END$$
DELIMITER ;
 
 
-- ============================================================
-- PART 2b: New trigger — FIFO lot-closing on SELL
--
-- Fires: AFTER INSERT on trade  (side = 'SELL')
-- What it does:
--   Walk through this account's OPEN / PARTIAL lots for the
--   sold stock, oldest-acquired first (FIFO).
--   Deduct the sold quantity from each lot in turn until the
--   full sell quantity is consumed.
--
--   For each lot touched:
--     • If sold qty >= lot's remaining_qty  → mark CLOSED
--     • If sold qty <  lot's remaining_qty  → reduce remaining,
--                                             mark PARTIAL
-- ============================================================
 
DELIMITER $$
CREATE TRIGGER trg_close_lots_fifo_after_sell
AFTER INSERT ON trade
FOR EACH ROW
BEGIN
    -- Only act on SELL trades
    IF NEW.side = 'SELL' THEN
 
        BEGIN
            DECLARE v_done           INT     DEFAULT 0;
            DECLARE v_lot_id         INT;
            DECLARE v_lot_remaining  DECIMAL(18,6);
            DECLARE v_qty_to_sell    DECIMAL(18,6);
            DECLARE v_inv_acct_id    INT;
 
            -- Resolve the investment account once
            SELECT investment_account_id INTO v_inv_acct_id
            FROM orders
            WHERE order_id = NEW.order_id;
 
            -- How many shares does this SELL trade need to consume?
            SET v_qty_to_sell = NEW.quantity;
 
            -- ── Cursor: OPEN + PARTIAL lots, FIFO order ──────
            BEGIN
                DECLARE cur_lots CURSOR FOR
                    SELECT lot_id, remaining_qty
                    FROM holding_lot
                    WHERE investment_account_id = v_inv_acct_id
                      AND stock_id              = NEW.stock_id
                      AND status               IN ('OPEN', 'PARTIAL')
                    ORDER BY acquired_at ASC;   -- ← FIFO (change to DESC for LIFO)
 
                DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
 
                OPEN cur_lots;
 
                lot_loop: LOOP
                    FETCH cur_lots INTO v_lot_id, v_lot_remaining;
 
                    -- Nothing more to iterate, or sell fully consumed
                    IF v_done = 1 OR v_qty_to_sell <= 0 THEN
                        LEAVE lot_loop;
                    END IF;
 
                    IF v_qty_to_sell >= v_lot_remaining THEN
                        -- ── This lot is fully consumed ────────
                        UPDATE holding_lot
                        SET remaining_qty = 0,
                            status        = 'CLOSED'
                        WHERE lot_id = v_lot_id;
 
                        SET v_qty_to_sell = v_qty_to_sell - v_lot_remaining;
 
                    ELSE
                        -- ── Lot is only partially consumed ────
                        UPDATE holding_lot
                        SET remaining_qty = remaining_qty - v_qty_to_sell,
                            status        = 'PARTIAL'
                        WHERE lot_id = v_lot_id;
 
                        SET v_qty_to_sell = 0;  -- fully satisfied
                    END IF;
 
                END LOOP;
 
                CLOSE cur_lots;
            END;
 
            -- ── Safety net ───────────────────────────────────
            -- If v_qty_to_sell > 0 here it means we ran out of
            -- OPEN/PARTIAL lots before consuming the full sell qty.
            -- This should never happen because trg_check_shares_before_sell
            -- already blocks overselling, but we log it defensively.
            IF v_qty_to_sell > 0 THEN
                INSERT INTO audit_log
                    (customer_id, action, entity_type, entity_id, new_value, source_time)
                SELECT ia.customer_id,
                       'LOT_FIFO_UNDERFLOW',
                       'TRADE',
                       NEW.trade_id,
                       CONCAT('Sell trade ', NEW.trade_id,
                              ' | stock_id=', NEW.stock_id,
                              ' | unmatched_qty=', v_qty_to_sell),
                       NOW()
                FROM orders o
                JOIN investment_account ia
                    ON o.investment_account_id = ia.investment_account_id
                WHERE o.order_id = NEW.order_id;
            END IF;
 
        END;
    END IF;
END$$
DELIMITER ;
-- ============================================================

-- ============================================================
-- TRIGGER 5 (UPDATED): Update daily_limit_usage after a trade
-- Now also recomputes risk_level dynamically after every trade(BUY).
-- risk_level = (total gross_traded_value today /
--               customer's max_order_value) * 100
-- If no risk profile exists, risk_level is left NULL.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_update_daily_limit_after_trade
AFTER INSERT ON trade
FOR EACH ROW
BEGIN
    DECLARE v_customer_id      INT;
    DECLARE v_max_order_value  DECIMAL(18,4);
    DECLARE v_new_gross_total  DECIMAL(18,4);
    DECLARE v_risk_level       DECIMAL(5,2);

    -- Only BUY trades consume the daily limit
    IF NEW.side = 'BUY' THEN

        SELECT ia.customer_id INTO v_customer_id
        FROM orders o
        JOIN investment_account ia ON o.investment_account_id = ia.investment_account_id
        WHERE o.order_id = NEW.order_id;

        SELECT rp.max_order_value INTO v_max_order_value
        FROM risk_profile rp
        WHERE rp.customer_id = v_customer_id
        LIMIT 1;

        INSERT INTO daily_limit_usage
            (customer_id, usage_date, trades_count, trades_value, gross_traded_value)
        VALUES
            (v_customer_id, CURDATE(), 1, NEW.gross_value, NEW.gross_value)
        ON DUPLICATE KEY UPDATE
            trades_count       = trades_count + 1,
            trades_value       = trades_value + NEW.gross_value,
            gross_traded_value = gross_traded_value + NEW.gross_value;

        SELECT gross_traded_value INTO v_new_gross_total
        FROM daily_limit_usage
        WHERE customer_id = v_customer_id
        AND   usage_date  = CURDATE();

        IF v_max_order_value IS NOT NULL AND v_max_order_value > 0 THEN
            SET v_risk_level = ROUND((v_new_gross_total / v_max_order_value) * 100, 2);
        ELSE
            SET v_risk_level = NULL;
        END IF;

        UPDATE daily_limit_usage
        SET risk_level = v_risk_level
        WHERE customer_id = v_customer_id
        AND   usage_date  = CURDATE();

    END IF;

END$$
DELIMITER ;


-- ============================================================
-- TRIGGER 6: Update account_balance after a bank transaction
-- Fires: AFTER INSERT on bank_txn
-- Why: Balance is always derived from transactions.
--      Every debit/credit automatically reflects in balance.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_update_balance_after_txn
AFTER INSERT ON bank_txn
FOR EACH ROW
BEGIN
    IF NEW.direction = 'IN' THEN
        UPDATE account_balance
        SET available_balance = available_balance + NEW.amount,
            txn_total_balance = txn_total_balance + NEW.amount,
            last_updated      = NOW()
        WHERE bank_account_id = NEW.bank_account_id
        AND currency_code     = NEW.currency_code;

    ELSEIF NEW.direction = 'OUT' THEN
        UPDATE account_balance
        SET available_balance = available_balance - NEW.amount,
            txn_total_balance = txn_total_balance - NEW.amount,
            last_updated      = NOW()
        WHERE bank_account_id = NEW.bank_account_id
        AND currency_code     = NEW.currency_code;
    END IF;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER 7: Block bank transaction if insufficient funds
-- Fires: BEFORE INSERT on bank_txn
-- Why: Prevents overdraft at DB level regardless of app code.
--      Even if application has a bug, balance can never go
--      negative.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_check_balance_before_txn
BEFORE INSERT ON bank_txn
FOR EACH ROW
BEGIN
    DECLARE v_available DECIMAL(18,4);

    IF NEW.direction = 'OUT' THEN
        SELECT available_balance INTO v_available
        FROM account_balance
        WHERE bank_account_id = NEW.bank_account_id
        AND currency_code     = NEW.currency_code;

        IF v_available IS NULL OR v_available < NEW.amount THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient funds for this transaction';
        END IF;
    END IF;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER 8: Auto-write audit log on KYC status change
-- Fires: AFTER UPDATE on customer
-- Why: Any KYC change is automatically logged. Admins cannot
--      change KYC status without it being recorded. The log
--      writes itself -- no manual INSERT needed.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_audit_kyc_change
AFTER UPDATE ON customer
FOR EACH ROW
BEGIN
    IF OLD.kyc_status != NEW.kyc_status THEN
        INSERT INTO audit_log
            (customer_id, action, entity_type, entity_id, new_value, source_time)
        VALUES
            (NEW.customer_id,
             'KYC_STATUS_CHANGE',
             'CUSTOMER',
             NEW.customer_id,
             CONCAT(OLD.kyc_status, ' -> ', NEW.kyc_status),
             NOW());
    END IF;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER 9: Block order on inactive/suspended account
-- Fires: BEFORE INSERT on orders
-- Why: A suspended or closed investment account should not
--      be able to place any orders regardless of app logic.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_check_account_status_before_order
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(50);

    SELECT status INTO v_status
    FROM investment_account
    WHERE investment_account_id = NEW.investment_account_id;

    IF v_status != 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot place order on a suspended or closed investment account';
    END IF;
END$$
DELIMITER ;


-- ============================================================
-- TRIGGER 10: Block order if stock is inactive/delisted
-- Fires: BEFORE INSERT on orders
-- Why: Prevents trading on delisted stocks like Boeing (BA)
--      which has is_active = 0 in our seed data.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_check_stock_active_before_order
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE v_is_active TINYINT(1);

    SELECT is_active INTO v_is_active
    FROM stock
    WHERE stock_id = NEW.stock_id;

    IF v_is_active = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot place order on a delisted or inactive stock';
    END IF;
END$$
DELIMITER ;


-- ============================================================
-- ENABLE EVENT SCHEDULER
-- Must be run once by a DBA or added to MySQL config.
-- Without this, the event below will not fire.
-- ============================================================
SET GLOBAL event_scheduler = ON;


-- ============================================================
-- SCHEDULED EVENT: Settle pending trades every day at 6am
--
-- What it does:
--   1. Finds all settlements where scheduled_date has passed
--      and status is still PENDING
--   2. Marks them as SETTLED and records the settled_at time
--   3. Writes an audit log entry for each settled trade
--
-- Why this exists:
--   Trades execute immediately but share ownership transfers
--   happen T+2 through the clearing house. This event
--   simulates the clearing house confirmation arriving and
--   automatically completing the settlement process.
--
-- Real world equivalent:
--   A message from NSCCL (India) or DTCC (US) confirming
--   that the shares have been officially delivered.
-- ============================================================
DELIMITER $$

CREATE EVENT evt_settle_pending_trades
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '06:00:00')
COMMENT 'Automatically settles trades whose T+2 date has passed'
DO
BEGIN
    DECLARE v_done          INT DEFAULT 0;
    DECLARE v_settlement_id INT;
    DECLARE v_trade_id      INT;
    DECLARE v_customer_id   INT;
    DECLARE v_ticker        VARCHAR(20);
    DECLARE v_quantity      DECIMAL(18,6);
    DECLARE v_gross_value   DECIMAL(18,4);

    -- Cursor over all settlements due for settlement
    DECLARE cur_settlements CURSOR FOR
        SELECT se.settlement_id,
               se.trade_id
        FROM settlement se
        WHERE se.status        = 'PENDING'
        AND se.scheduled_date <= CURDATE();

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur_settlements;

    settlement_loop: LOOP
        FETCH cur_settlements INTO v_settlement_id, v_trade_id;

        IF v_done = 1 THEN
            LEAVE settlement_loop;
        END IF;

        -- 1. Mark settlement as SETTLED
        UPDATE settlement
        SET status     = 'SETTLED',
            settled_at = NOW()
        WHERE settlement_id = v_settlement_id;

        -- 2. Get trade details for audit log
        SELECT t.quantity, t.gross_value,
               s.ticker,
               ia.customer_id
        INTO   v_quantity, v_gross_value,
               v_ticker,
               v_customer_id
        FROM trade t
        JOIN orders o              ON t.order_id             = o.order_id
        JOIN investment_account ia ON o.investment_account_id = ia.investment_account_id
        JOIN stock s               ON t.stock_id              = s.stock_id
        WHERE t.trade_id = v_trade_id;

        -- 3. Write audit log entry for this settlement
        INSERT INTO audit_log (
            customer_id,
            action,
            entity_type,
            entity_id,
            new_value,
            source_time
        ) VALUES (
            v_customer_id,
            'TRADE_SETTLED',
            'SETTLEMENT',
            v_settlement_id,
            CONCAT('Trade ', v_trade_id, ' | ', v_ticker,
                   ' | qty=', v_quantity,
                   ' | value=', v_gross_value,
                   ' | SETTLED'),
            NOW()
        );

    END LOOP;

    CLOSE cur_settlements;

END$$

DELIMITER ;


-- ============================================================
-- HOW TO VERIFY THE EVENT IS REGISTERED:
--   SELECT * FROM information_schema.EVENTS
--   WHERE EVENT_NAME = 'evt_settle_pending_trades';
--
-- HOW TO MANUALLY TRIGGER IT FOR TESTING
-- (without waiting for 6am tomorrow):
--   CALL settle_now();
-- ============================================================
DELIMITER $$

CREATE PROCEDURE settle_now()
COMMENT 'Manually triggers settlement — use for testing only'
BEGIN
    DECLARE v_done          INT DEFAULT 0;
    DECLARE v_settlement_id INT;
    DECLARE v_trade_id      INT;
    DECLARE v_customer_id   INT;
    DECLARE v_ticker        VARCHAR(20);
    DECLARE v_quantity      DECIMAL(18,6);
    DECLARE v_gross_value   DECIMAL(18,4);

    DECLARE cur_settlements CURSOR FOR
        SELECT se.settlement_id, se.trade_id
        FROM settlement se
        WHERE se.status = 'PENDING'
        AND se.scheduled_date <= CURDATE();

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur_settlements;

    settlement_loop: LOOP
        FETCH cur_settlements INTO v_settlement_id, v_trade_id;

        IF v_done = 1 THEN
            LEAVE settlement_loop;
        END IF;

        UPDATE settlement
        SET status     = 'SETTLED',
            settled_at = NOW()
        WHERE settlement_id = v_settlement_id;

        SELECT t.quantity, t.gross_value, s.ticker, ia.customer_id
        INTO   v_quantity, v_gross_value, v_ticker, v_customer_id
        FROM trade t
        JOIN orders o              ON t.order_id              = o.order_id
        JOIN investment_account ia ON o.investment_account_id = ia.investment_account_id
        JOIN stock s               ON t.stock_id              = s.stock_id
        WHERE t.trade_id = v_trade_id;

        INSERT INTO audit_log (
            customer_id, action, entity_type, entity_id, new_value, source_time
        ) VALUES (
            v_customer_id,
            'TRADE_SETTLED',
            'SETTLEMENT',
            v_settlement_id,
            CONCAT('Trade ', v_trade_id, ' | ', v_ticker,
                   ' | qty=', v_quantity,
                   ' | value=', v_gross_value,
                   ' | SETTLED'),
            NOW()
        );

    END LOOP;

    CLOSE cur_settlements;

    -- Show what was settled
    SELECT settlement_id, trade_id, status, settled_at
    FROM settlement
    WHERE status = 'SETTLED'
    ORDER BY settled_at DESC
    LIMIT 20;

END$$

DELIMITER ;


-- ============================================================
-- TRIGGER 11: Block order if customer KYC is not verified
-- Fires: BEFORE INSERT on orders
-- Why: The application layer checks KYC in authenticate_customer()
--      but that can be bypassed if someone calls the DB directly.
--      This trigger enforces KYC at the database level -- the
--      last line of defence regardless of how the order arrives.
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_check_kyc_before_order
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE v_kyc_status VARCHAR(50);

    SELECT c.kyc_status INTO v_kyc_status
    FROM investment_account ia
    JOIN customer c ON ia.customer_id = c.customer_id
    WHERE ia.investment_account_id = NEW.investment_account_id;

    IF v_kyc_status IS NULL OR v_kyc_status != 'VERIFIED' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Customer KYC is not verified. Cannot place order.';
    END IF;
END$$
DELIMITER ;