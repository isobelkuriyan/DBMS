-- ============================================================
-- TRADE AND PORTFOLIO PLATFORM — DATABASE SCHEMA
-- MySQL 8.0+  |  2026-01-24
-- ============================================================

CREATE DATABASE IF NOT EXISTS tradeplatformm
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE tradeplatformm;

SET FOREIGN_KEY_CHECKS = 0;

-- -
-- 1.  LOOKUP / REFERENCE TABLES
-- -

CREATE TABLE currency (
    currency_code   VARCHAR(10)   NOT NULL,
    name            VARCHAR(100)  NOT NULL,
    symbol          VARCHAR(10)   NOT NULL,
    PRIMARY KEY (currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE stock (
    stock_id        INT           NOT NULL AUTO_INCREMENT,
    ticker          VARCHAR(20)   NOT NULL,
    company_name    VARCHAR(255)  NOT NULL,
    exchange        VARCHAR(100)  NULL,
    is_active       TINYINT(1)    NOT NULL DEFAULT 1,
    PRIMARY KEY (stock_id),
    UNIQUE KEY uq_stock_ticker (ticker)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE branch (
    branch_id       INT           NOT NULL AUTO_INCREMENT,
    fbs             VARCHAR(100)  NULL,
    city            VARCHAR(100)  NULL,
    PRIMARY KEY (branch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 2.  USER / AUTH TABLES
-- -

CREATE TABLE customer (
    customer_id     INT           NOT NULL AUTO_INCREMENT,
    name            VARCHAR(255)  NOT NULL,
    email           VARCHAR(255)  NOT NULL,
    phone           VARCHAR(50)   NULL,
    kyc_status      ENUM('PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'PENDING',
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id),
    UNIQUE KEY uq_customer_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE customer_identity (
    customer_id   INT          NOT NULL,
    doc_type      ENUM('AADHAR','PAN','PASSPORT','DRIVING_LICENCE','VOTER_ID') NOT NULL,
    doc_number    VARCHAR(50)  NOT NULL,
    verified      TINYINT(1)   NOT NULL DEFAULT 0,
    expiry_date   DATE         NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id, doc_type),
    UNIQUE KEY uq_doc_number (doc_number),
    CONSTRAINT fk_cust_identity_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE admin (
    admin_id              INT           NOT NULL AUTO_INCREMENT,
    event                 VARCHAR(255)  NULL,
    email                 VARCHAR(255)  NOT NULL,
    password_hash         VARCHAR(255)  NOT NULL,
    status                ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    role_id               INT           NULL,
    created_by_admin_id   INT           NULL,
    PRIMARY KEY (admin_id),
    UNIQUE KEY uq_admin_email (email),
    CONSTRAINT fk_admin_role        FOREIGN KEY (role_id)            REFERENCES admin_role(role_id),
    CONSTRAINT fk_admin_self        FOREIGN KEY (created_by_admin_id) REFERENCES admin(admin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE admin_role (
    role_id         INT           NOT NULL AUTO_INCREMENT,
    role_name       VARCHAR(100)  NOT NULL,
    PRIMARY KEY (role_id),
    UNIQUE KEY uq_role_name (role_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 3.  INVESTMENT ACCOUNT & BANK
-- -

CREATE TABLE investment_account (
    investment_account_id   INT           NOT NULL AUTO_INCREMENT,
    customer_id             INT           NOT NULL,
    broker_number           VARCHAR(100)  NULL,
    status                  ENUM('ACTIVE','SUSPENDED','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    opened_at               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (investment_account_id),
    CONSTRAINT fk_inv_acct_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE bank_account (
    bank_account_id         INT           NOT NULL AUTO_INCREMENT,
    customer_id             INT           NOT NULL,
    branch_id               INT           NULL,
    account_number          VARCHAR(100)  NOT NULL,
    account_type            ENUM('SAVINGS','CURRENT','MARGIN') NOT NULL,
    status                  VARCHAR(50)   NOT NULL DEFAULT 'ACTIVE',
    opened_id               INT           NULL,
    PRIMARY KEY (bank_account_id),
    UNIQUE KEY uq_bank_account_number (account_number),
    CONSTRAINT fk_bank_acct_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_bank_acct_branch   FOREIGN KEY (branch_id)   REFERENCES branch(branch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE bank_txn (
    bank_txn_id             INT           NOT NULL AUTO_INCREMENT,
    bank_account_id         INT           NOT NULL,
    txn_type                ENUM('DEBIT','CREDIT','TRANSFER') NOT NULL,
    direction               ENUM('IN','OUT') NOT NULL,
    amount                  DECIMAL(18,4) NOT NULL,
    currency_code           VARCHAR(10)   NOT NULL,
    txn_time                DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description             TEXT          NULL,
    reference_type          VARCHAR(100)  NULL,
    reference_id            INT           NULL,
    counterparty_account_id INT           NULL,
    PRIMARY KEY (bank_txn_id),
    CONSTRAINT chk_bank_txn_amount     CHECK (amount > 0),
    CONSTRAINT fk_bank_txn_account     FOREIGN KEY (bank_account_id)         REFERENCES bank_account(bank_account_id),
    CONSTRAINT fk_bank_txn_currency    FOREIGN KEY (currency_code)            REFERENCES currency(currency_code),
    CONSTRAINT fk_bank_txn_counterparty FOREIGN KEY (counterparty_account_id) REFERENCES bank_account(bank_account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE account_balance (
    bank_account_id         INT           NOT NULL,
    currency_code           VARCHAR(10)   NOT NULL,
    txn_total_balance       DECIMAL(18,4) NOT NULL DEFAULT 0,
    available_balance       DECIMAL(18,4) NOT NULL DEFAULT 0,
    blocked_balance         DECIMAL(18,4) NOT NULL DEFAULT 0,
    last_updated            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (bank_account_id, currency_code),
    CONSTRAINT chk_available_balance   CHECK (available_balance >= 0),
    CONSTRAINT chk_blocked_balance     CHECK (blocked_balance >= 0),
    CONSTRAINT fk_acct_balance_account  FOREIGN KEY (bank_account_id) REFERENCES bank_account(bank_account_id),
    CONSTRAINT fk_acct_balance_currency FOREIGN KEY (currency_code)   REFERENCES currency(currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 4.  PORTFOLIO
-- -

CREATE TABLE portfolio_holding (
    holding_id              INT           NOT NULL AUTO_INCREMENT,
    investment_account_id   INT           NOT NULL,
    stock_id                INT           NOT NULL,
    quantity                DECIMAL(18,6) NOT NULL DEFAULT 0,
    blocked_quantity        DECIMAL(18,6) NOT NULL DEFAULT 0,
    avg_buy_price           DECIMAL(18,6) NULL,
    last_updated            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (holding_id),
    UNIQUE KEY uq_holding_acct_stock (investment_account_id, stock_id),
    CONSTRAINT chk_holding_quantity         CHECK (quantity >= 0),
    CONSTRAINT chk_holding_blocked_quantity CHECK (blocked_quantity >= 0),
    CONSTRAINT fk_holding_inv_acct FOREIGN KEY (investment_account_id) REFERENCES investment_account(investment_account_id),
    CONSTRAINT fk_holding_stock    FOREIGN KEY (stock_id)              REFERENCES stock(stock_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE stock_price (
    price_id                INT           NOT NULL AUTO_INCREMENT,
    stock_id                INT           NOT NULL,
    price                   DECIMAL(18,6) NOT NULL,
    currency_code           VARCHAR(10)   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    as_of_time              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (price_id),
    CONSTRAINT chk_stock_price          CHECK (price > 0),
    CONSTRAINT fk_stock_price_stock     FOREIGN KEY (stock_id)     REFERENCES stock(stock_id),
    CONSTRAINT fk_stock_price_currency  FOREIGN KEY (currency_code) REFERENCES currency(currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 5.  WATCHLIST & RISK
-- -

CREATE TABLE watchlist (
    watchlist_id            INT           NOT NULL AUTO_INCREMENT,
    watchlist_bl_id         INT           NULL,
    customer_id             INT           NOT NULL,
    company_id_code         VARCHAR(100)  NULL,
    PRIMARY KEY (watchlist_id),
    CONSTRAINT fk_watchlist_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE watchlist_item (
    item_id                 INT           NOT NULL AUTO_INCREMENT,
    watchlist_id            INT           NOT NULL,
    stock_id                INT           NOT NULL,
    PRIMARY KEY (item_id),
    UNIQUE KEY uq_watchlist_item (watchlist_id, stock_id),
    CONSTRAINT fk_wl_item_watchlist FOREIGN KEY (watchlist_id) REFERENCES watchlist(watchlist_id),
    CONSTRAINT fk_wl_item_stock     FOREIGN KEY (stock_id)     REFERENCES stock(stock_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE risk_profile (
    risk_profile_id         INT           NOT NULL AUTO_INCREMENT,
    customer_id             INT           NOT NULL,
    profile_name            VARCHAR(100)  NULL,
    max_order_value         DECIMAL(18,4) NULL,
    created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (risk_profile_id),
    CONSTRAINT fk_risk_profile_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE daily_limit_usage (
    usage_id                INT           NOT NULL AUTO_INCREMENT,
    customer_id             INT           NOT NULL,
    usage_date              DATE          NOT NULL,
    trades_count            INT           NOT NULL DEFAULT 0,
    trades_value            DECIMAL(18,4) NOT NULL DEFAULT 0,
    gross_traded_value      DECIMAL(18,4) NOT NULL DEFAULT 0,
    risk_level              DECIMAL(5,2)  NULL,
    PRIMARY KEY (usage_id),
    UNIQUE KEY uq_daily_limit (customer_id, usage_date),
    CONSTRAINT chk_daily_trades_count CHECK (trades_count >= 0),
    CONSTRAINT fk_daily_limit_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE admin_role_map (
    map_id                  INT           NOT NULL AUTO_INCREMENT,
    admin_id                INT           NOT NULL,
    entity_type             VARCHAR(50)   NULL,
    entity_id               INT           NULL,
    PRIMARY KEY (map_id),
    CONSTRAINT fk_admin_role_map_admin FOREIGN KEY (admin_id) REFERENCES admin(admin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 6.  AUDIT
-- -

CREATE TABLE audit_log (
    audit_id                INT           NOT NULL AUTO_INCREMENT,
    customer_id             INT           NULL,
    stock_id                INT           NULL,
    action                  VARCHAR(100)  NOT NULL,
    entity_type             VARCHAR(100)  NULL,
    entity_id               INT           NULL,
    role_value              VARCHAR(100)  NULL,
    role_nature             VARCHAR(100)  NULL,
    new_value               TEXT          NULL,
    max_value               DECIMAL(18,4) NULL,
    source_time             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (audit_id),
    CONSTRAINT fk_audit_log_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_audit_log_stock    FOREIGN KEY (stock_id)    REFERENCES stock(stock_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE price_alert (
    alert_id                INT           NOT NULL AUTO_INCREMENT,
    customer_id             INT           NOT NULL,
    stock_id                INT           NOT NULL,
    `condition`             ENUM('ABOVE','BELOW') NOT NULL,
    seed_time               DATETIME      NULL,
    trigger_price           DECIMAL(18,6) NOT NULL,
    is_active               TINYINT(1)    NOT NULL DEFAULT 1,
    created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (alert_id),
    CONSTRAINT chk_trigger_price        CHECK (trigger_price > 0),
    CONSTRAINT fk_price_alert_customer  FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_price_alert_stock     FOREIGN KEY (stock_id)    REFERENCES stock(stock_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 7.  CORPORATE ACTIONS
-- -

CREATE TABLE corporate_action (
    action_id               INT           NOT NULL AUTO_INCREMENT,
    investment_account_id   INT           NOT NULL,
    stock_id                INT           NOT NULL,
    action_type             VARCHAR(100)  NOT NULL,
    ex_allot                DECIMAL(18,6) NULL,
    record_date             DATE          NULL,
    pay_date                DATE          NULL,
    dividend_per_share      DECIMAL(18,6) NULL,
    ratio                   DECIMAL(18,6) NULL,
    last_updated            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (action_id),
    CONSTRAINT fk_corp_action_inv_acct FOREIGN KEY (investment_account_id) REFERENCES investment_account(investment_account_id),
    CONSTRAINT fk_corp_action_stock    FOREIGN KEY (stock_id)              REFERENCES stock(stock_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 8.  ORDERS
-- -

CREATE TABLE orders (
    order_id                INT           NOT NULL AUTO_INCREMENT,
    order_ref_id            VARCHAR(100)  NULL,
    investment_account_id   INT           NOT NULL,
    stock_id                INT           NOT NULL,
    order_type              ENUM('MARKET','LIMIT','STOP','STOP_LIMIT') NOT NULL,
    quantity                DECIMAL(18,6) NOT NULL,
    limit_price             DECIMAL(18,6) NULL,
    trigger_price           DECIMAL(18,6) NULL,
    side                    ENUM('BUY','SELL') NOT NULL,
    currency_code           VARCHAR(10)   NOT NULL,
    payment_method          ENUM('BANK','CARD') NOT NULL DEFAULT 'BANK',
    card_id                 INT           NULL,
    reserved_amount         DECIMAL(18,4) NULL,
    reserved_shares         DECIMAL(18,6) NULL,
    status                  ENUM('PENDING','OPEN','PARTIAL','FILLED','CANCELLED','REJECTED') NOT NULL DEFAULT 'PENDING',
    cancelled_at            DATETIME      NULL,
    created_at              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    chosen_bank_account_id  INT           NULL,   -- set by Trigger 2, read by Python
    PRIMARY KEY (order_id),
    UNIQUE KEY uq_order_ref_id (order_ref_id),
    
	-- and update the FK section at the bottom of that table:
	CONSTRAINT fk_orders_chosen_bank FOREIGN KEY (chosen_bank_account_id)
    REFERENCES bank_account(bank_account_id),
    CONSTRAINT chk_order_quantity       CHECK (quantity > 0),
    CONSTRAINT fk_orders_inv_acct       FOREIGN KEY (investment_account_id) REFERENCES investment_account(investment_account_id),
    CONSTRAINT fk_orders_stock          FOREIGN KEY (stock_id)              REFERENCES stock(stock_id),
    CONSTRAINT fk_orders_currency       FOREIGN KEY (currency_code)         REFERENCES currency(currency_code),
    CONSTRAINT fk_orders_card           FOREIGN KEY (card_id)               REFERENCES card(card_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_fill (
    fill_id                 INT           NOT NULL AUTO_INCREMENT,
    order_id                INT           NOT NULL,
    filled_qty              DECIMAL(18,6) NOT NULL,
    fill_price              DECIMAL(18,6) NOT NULL,
    currency_code           VARCHAR(10)   NOT NULL,
    fill_time               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (fill_id),
    CONSTRAINT chk_fill_qty             CHECK (filled_qty > 0),
    CONSTRAINT chk_fill_price           CHECK (fill_price > 0),
    CONSTRAINT fk_order_fill_order      FOREIGN KEY (order_id)     REFERENCES orders(order_id),
    CONSTRAINT fk_order_fill_currency   FOREIGN KEY (currency_code) REFERENCES currency(currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 9.  TRADES
-- -

CREATE TABLE trade (
    trade_id                INT           NOT NULL AUTO_INCREMENT,
    fill_id                 INT           NOT NULL,
    order_id                INT           NOT NULL,
    stock_id                INT           NOT NULL,
    side                    ENUM('BUY','SELL') NOT NULL,
    quantity                DECIMAL(18,6) NOT NULL,
    price                   DECIMAL(18,6) NOT NULL,
    currency_code           VARCHAR(10)   NOT NULL,
    gross_value             DECIMAL(18,4) NOT NULL,
    trade_time              DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (trade_id),
    CONSTRAINT chk_trade_quantity   CHECK (quantity > 0),
    CONSTRAINT chk_trade_price      CHECK (price > 0),
    CONSTRAINT fk_trade_fill        FOREIGN KEY (fill_id)      REFERENCES order_fill(fill_id),
    CONSTRAINT fk_trade_order       FOREIGN KEY (order_id)     REFERENCES orders(order_id),
    CONSTRAINT fk_trade_stock       FOREIGN KEY (stock_id)     REFERENCES stock(stock_id),
    CONSTRAINT fk_trade_currency    FOREIGN KEY (currency_code) REFERENCES currency(currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE trade_charge (
    trade_charge_id         INT           NOT NULL AUTO_INCREMENT,
    trade_id                INT           NOT NULL,
    fee_rule_id             INT           NULL,
    fee_rule_bl             INT           NULL,
    available_limit         DECIMAL(18,4) NULL,
    free_type               VARCHAR(100)  NULL,
    free_lock_bl            DECIMAL(18,4) NULL,
    amount                  DECIMAL(18,4) NOT NULL,
    PRIMARY KEY (trade_charge_id),
    CONSTRAINT chk_charge_amount    CHECK (amount >= 0),
    CONSTRAINT fk_trade_charge_trade FOREIGN KEY (trade_id) REFERENCES trade(trade_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 10.  SETTLEMENT & PAYMENT
-- -

CREATE TABLE settlement (
    settlement_id           INT           NOT NULL AUTO_INCREMENT,
    payment_id              INT           NULL,
    trade_id                INT           NOT NULL,
    investment_account_id   INT           NOT NULL,
    card_id                 INT           NULL,
    currency_code           VARCHAR(10)   NOT NULL,
    scheduled_date          DATE          NULL,
    settled_at              DATETIME      NULL,
    status                  ENUM('PENDING','SETTLED','FAILED') NOT NULL DEFAULT 'PENDING',
    payment_method          VARCHAR(100)  NULL,
    PRIMARY KEY (settlement_id),
    CONSTRAINT fk_settlement_trade    FOREIGN KEY (trade_id)              REFERENCES trade(trade_id),
    CONSTRAINT fk_settlement_inv_acct FOREIGN KEY (investment_account_id) REFERENCES investment_account(investment_account_id),
    CONSTRAINT fk_settlement_currency FOREIGN KEY (currency_code)         REFERENCES currency(currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE trade_payment (
    payment_id              INT           NOT NULL AUTO_INCREMENT,
    order_id                INT           NOT NULL,
    trade_id                INT           NOT NULL,
    buy_trade_id            INT           NULL,
    sell_trade_id           INT           NULL,
    status                  ENUM('PENDING','COMPLETED','FAILED') NOT NULL DEFAULT 'PENDING',
    payment_method          VARCHAR(100)  NULL,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_trade_payment_order      FOREIGN KEY (order_id)     REFERENCES orders(order_id),
    CONSTRAINT fk_trade_payment_trade      FOREIGN KEY (trade_id)     REFERENCES trade(trade_id),
    CONSTRAINT fk_trade_payment_buy_trade  FOREIGN KEY (buy_trade_id)  REFERENCES trade(trade_id),
    CONSTRAINT fk_trade_payment_sell_trade FOREIGN KEY (sell_trade_id) REFERENCES trade(trade_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE holding_lot (
    lot_id                  INT           NOT NULL AUTO_INCREMENT,
    settlement_id           INT           NOT NULL,
    investment_account_id   INT           NOT NULL,
    stock_id                INT           NOT NULL,
    status                  ENUM('OPEN','CLOSED','PARTIAL') NOT NULL DEFAULT 'OPEN',
    quantity                DECIMAL(18,6) NOT NULL DEFAULT 0
        COMMENT 'Original shares purchased in this lot',
    remaining_qty           DECIMAL(18,6) NOT NULL DEFAULT 0
        COMMENT 'Shares still open (not yet sold)',
    buy_price               DECIMAL(18,6) NULL
        COMMENT 'Cost basis per share for this lot',
    acquired_at             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
        COMMENT 'When this lot was created (BUY trade time)',
    PRIMARY KEY (lot_id),
    CONSTRAINT chk_lot_remaining CHECK (remaining_qty <= quantity),
    CONSTRAINT chk_lot_qty_pos   CHECK (quantity >= 0),
    CONSTRAINT chk_lot_rem_pos   CHECK (remaining_qty >= 0),
    CONSTRAINT fk_holding_lot_settlement FOREIGN KEY (settlement_id)         REFERENCES settlement(settlement_id),
    CONSTRAINT fk_holding_lot_inv_acct   FOREIGN KEY (investment_account_id) REFERENCES investment_account(investment_account_id),
    CONSTRAINT fk_holding_lot_stock      FOREIGN KEY (stock_id)              REFERENCES stock(stock_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- -
-- 11.  FEE RULES
-- -

CREATE TABLE fee_rule (
    fee_rule_id             INT           NOT NULL AUTO_INCREMENT,
    investment_account_id   INT           NOT NULL,
    fee_type                VARCHAR(100)  NOT NULL,
    rate                    DECIMAL(10,6) NOT NULL,
    min_fee                 DECIMAL(18,4) NULL,
    max_fee                 DECIMAL(18,4) NULL,
    effective_from          DATE          NOT NULL,
    effective_to            DATE          NULL,
    is_active               TINYINT(1)    NOT NULL DEFAULT 1,
    PRIMARY KEY (fee_rule_id),
    CONSTRAINT chk_fee_rule_rate    CHECK (rate >= 0),
    CONSTRAINT chk_fee_rule_max_fee CHECK (max_fee IS NULL OR max_fee >= min_fee),
    CONSTRAINT fk_fee_rule_inv_acct FOREIGN KEY (investment_account_id) REFERENCES investment_account(investment_account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 12.  CARDS
-- -

CREATE TABLE card (
    card_id                 INT           NOT NULL AUTO_INCREMENT,
    customer_id             INT           NOT NULL,
    card_type               ENUM('DEBIT','CREDIT','PREPAID') NOT NULL,
    currency_code           VARCHAR(10)   NOT NULL,
    description             TEXT          NULL,
    issued_at               DATETIME      NULL,
    issued_by               INT           NULL,
    effective_from          DATE          NULL,
    expiry_date             DATE          NULL,
    status                  ENUM('ACTIVE','BLOCKED','EXPIRED','CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    PRIMARY KEY (card_id),
    CONSTRAINT chk_card_expiry      CHECK (expiry_date IS NULL OR expiry_date > effective_from),
    CONSTRAINT fk_card_customer     FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_card_issued_by    FOREIGN KEY (issued_by)   REFERENCES admin(admin_id),
    CONSTRAINT fk_card_currency     FOREIGN KEY (currency_code) REFERENCES currency(currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE card_limit (
    card_limit_id           INT           NOT NULL AUTO_INCREMENT,
    card_id                 INT           NOT NULL,
    direction               ENUM('IN','OUT') NOT NULL,
    float_amount            DECIMAL(18,4) NOT NULL,
    maximum                 DECIMAL(18,4) NOT NULL,
    txn_time                DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (card_limit_id),
    CONSTRAINT chk_card_limit_float   CHECK (float_amount >= 0),
    CONSTRAINT chk_card_limit_maximum CHECK (maximum >= 0),
    CONSTRAINT fk_card_limit_card FOREIGN KEY (card_id) REFERENCES card(card_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE fx_policy (
    fx_policy_id            INT           NOT NULL AUTO_INCREMENT,
    card_id                 INT           NOT NULL,
    direction               ENUM('IN','OUT') NOT NULL,
    fx_markup_percent       DECIMAL(10,6) NOT NULL DEFAULT 0,
    fx_max_time             DATETIME      NULL,
    class_source            VARCHAR(100)  NULL,
    PRIMARY KEY (fx_policy_id),
    CONSTRAINT chk_fx_markup    CHECK (fx_markup_percent >= 0),
    CONSTRAINT fk_fx_policy_card FOREIGN KEY (card_id) REFERENCES card(card_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE credit_card_details (
    credit_card_id          INT           NOT NULL AUTO_INCREMENT,
    card_id                 INT           NOT NULL,
    trade_id                INT           NOT NULL,
    fee_rule_bl             INT           NULL,
    available_limit         DECIMAL(18,4) NOT NULL,
    free_type_bl            DECIMAL(18,4) NULL,
    free_lock_type          VARCHAR(100)  NULL,
    used_amount             DECIMAL(18,4) NOT NULL DEFAULT 0,
    PRIMARY KEY (credit_card_id),
    CONSTRAINT chk_cc_available_limit CHECK (available_limit >= 0),
    CONSTRAINT chk_cc_used_amount     CHECK (used_amount >= 0),
    CONSTRAINT fk_cc_details_card     FOREIGN KEY (card_id)  REFERENCES card(card_id),
    CONSTRAINT fk_cc_details_trade    FOREIGN KEY (trade_id) REFERENCES trade(trade_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -
-- 13. EXCHANGE RATE
-- -
CREATE TABLE exchange_rate (
    base_currency           VARCHAR(10)   NOT NULL,
    quote_currency          VARCHAR(10)   NOT NULL,
    rate                    DECIMAL(18,6) NOT NULL,
    bank_fx_markup_percent  DECIMAL(10,6) NOT NULL DEFAULT 0.010000,
    last_updated            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (base_currency, quote_currency),
    CONSTRAINT fk_er_base  FOREIGN KEY (base_currency)  REFERENCES currency(currency_code),
    CONSTRAINT fk_er_quote FOREIGN KEY (quote_currency) REFERENCES currency(currency_code),
    CONSTRAINT chk_er_rate   CHECK (rate > 0),
    CONSTRAINT chk_er_markup CHECK (bank_fx_markup_percent >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SET FOREIGN_KEY_CHECKS = 1;

-- -
-- INDEXES  (PKs and UNIQUEs are already indexed above)
-- -

-- Non-FK, non-PK columns that benefit from explicit indexing:
CREATE INDEX idx_customer_kyc            ON customer(kyc_status);
CREATE INDEX idx_stock_exchange          ON stock(exchange);
CREATE INDEX idx_stock_price_stock_time  ON stock_price(stock_id, as_of_time);
CREATE INDEX idx_orders_status           ON orders(status);
CREATE INDEX idx_orders_created          ON orders(created_at);
CREATE INDEX idx_trade_time              ON trade(trade_time);
CREATE INDEX idx_bank_txn_time           ON bank_txn(txn_time);
CREATE INDEX idx_settlement_status       ON settlement(status);
CREATE INDEX idx_settlement_scheduled    ON settlement(scheduled_date);
CREATE INDEX idx_price_alert_stock       ON price_alert(stock_id, is_active);
CREATE INDEX idx_holding_lot_fifo ON holding_lot (investment_account_id, stock_id, acquired_at);