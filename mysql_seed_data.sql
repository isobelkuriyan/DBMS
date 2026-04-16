-- ============================================================
-- TRADE AND PORTFOLIO PLATFORM — SIMULATED DATA
-- MySQL 8.0+  |  2026-01-24
-- ============================================================

USE tradeplatformm;

SET FOREIGN_KEY_CHECKS = 0;

-- -
-- 1. CURRENCIES
-- -
INSERT INTO currency (currency_code, name, symbol) VALUES
  ('USD', 'US Dollar',         '$'),
  ('EUR', 'Euro',              '€'),
  ('GBP', 'British Pound',     '£'),
  ('INR', 'Indian Rupee',      '₹'),
  ('JPY', 'Japanese Yen',      '¥'),
  ('CAD', 'Canadian Dollar',   'C$'),
  ('AUD', 'Australian Dollar', 'A$'),
  ('SGD', 'Singapore Dollar',  'S$');

-- -
-- 2. STOCKS
-- -
INSERT INTO stock (ticker, company_name, exchange, is_active) VALUES
  ('AAPL',  'Apple Inc.',                 'NASDAQ', 1),
  ('MSFT',  'Microsoft Corporation',      'NASDAQ', 1),
  ('GOOGL', 'Alphabet Inc.',              'NASDAQ', 1),
  ('AMZN',  'Amazon.com Inc.',            'NASDAQ', 1),
  ('TSLA',  'Tesla Inc.',                 'NASDAQ', 1),
  ('JPM',   'JPMorgan Chase & Co.',       'NYSE',   1),
  ('GS',    'Goldman Sachs Group Inc.',   'NYSE',   1),
  ('V',     'Visa Inc.',                  'NYSE',   1),
  ('NVDA',  'NVIDIA Corporation',         'NASDAQ', 1),
  ('META',  'Meta Platforms Inc.',        'NASDAQ', 1),
  ('NFLX',  'Netflix Inc.',               'NASDAQ', 1),
  ('BABA',  'Alibaba Group Holding Ltd.', 'NYSE',   1),
  ('BRK',   'Berkshire Hathaway Inc.',    'NYSE',   1),
  ('DIS',   'The Walt Disney Company',    'NYSE',   1),
  ('BA',    'The Boeing Company',         'NYSE',   0);

-- -
-- 3. BRANCHES
-- -
INSERT INTO branch (fbs, city) VALUES
  ('FBS-WEST-01',  'San Francisco'),
  ('FBS-WEST-02',  'Seattle'),
  ('FBS-WEST-03',  'Mountain View'),
  ('FBS-EAST-01',  'New York'),
  ('FBS-EAST-02',  'Boston'),
  ('FBS-EAST-03',  'New York'),
  ('FBS-EAST-04',  'Chicago'),
  ('FBS-SOUTH-01', 'Dallas'),
  ('FBS-WEST-04',  'San Jose'),
  ('FBS-EAST-05',  'Miami');

-- -
-- 4. CUSTOMERS
-- -
INSERT INTO customer (name, email, phone, kyc_status, created_at) VALUES
  ('Alice Johnson',  'alice@example.com',  '+1-555-0101', 'VERIFIED', DATE_SUB(NOW(), INTERVAL 2 YEAR)),
  ('Bob Smith',      'bob@example.com',    '+1-555-0102', 'VERIFIED', DATE_SUB(NOW(), INTERVAL 18 MONTH)),
  ('Carol Williams', 'carol@example.com',  '+1-555-0103', 'VERIFIED', DATE_SUB(NOW(), INTERVAL 1 YEAR)),
  ('David Lee',      'david@example.com',  '+1-555-0104', 'PENDING',  DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  ('Eva Brown',      'eva@example.com',    '+1-555-0105', 'VERIFIED', DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  ('Frank Garcia',   'frank@example.com',  '+44-7700-001','VERIFIED', DATE_SUB(NOW(), INTERVAL 14 MONTH)),
  ('Grace Martinez', 'grace@example.com',  '+44-7700-002','VERIFIED', DATE_SUB(NOW(), INTERVAL 3 YEAR)),
  ('Henry Wilson',   'henry@example.com',  '+91-9800-001','VERIFIED', DATE_SUB(NOW(), INTERVAL 2 YEAR)),
  ('Irene Taylor',   'irene@example.com',  '+91-9800-002','REJECTED', DATE_SUB(NOW(), INTERVAL 3 MONTH)),
  ('James Anderson', 'james@example.com',  '+1-555-0110', 'VERIFIED', DATE_SUB(NOW(), INTERVAL 5 YEAR));

-- -
-- 4b. CUSTOMER IDENTITY DOCUMENTS
-- -
INSERT INTO customer_identity (customer_id, doc_type, doc_number, verified, expiry_date) VALUES
  (1,  'AADHAR',          '2345-6789-0123', 1, NULL),
  (1,  'PAN',             'ABCPJ1234A',     1, NULL),
  (2,  'AADHAR',          '3456-7890-1234', 1, NULL),
  (2,  'PAN',             'BCDQK2345B',     1, NULL),
  (3,  'AADHAR',          '4567-8901-2345', 1, NULL),
  (3,  'PASSPORT',        'P1234567',       1, '2028-06-30'),
  (4,  'AADHAR',          '5678-9012-3456', 0, NULL),
  (5,  'AADHAR',          '6789-0123-4567', 1, NULL),
  (5,  'PAN',             'CDER L3456C',    1, NULL),
  (6,  'PASSPORT',        'P7654321',       1, '2027-03-15'),
  (7,  'PASSPORT',        'P2345678',       1, '2029-11-20'),
  (8,  'AADHAR',          '7890-1234-5678', 1, NULL),
  (8,  'PAN',             'DEFGM4567D',     1, NULL),
  (9,  'AADHAR',          '8901-2345-6789', 0, NULL),
  (10, 'AADHAR',          '9012-3456-7890', 1, NULL),
  (10, 'PAN',             'EFGHN5678E',     1, NULL),
  (10, 'PASSPORT',        'P3456789',       1, '2026-08-10');

-- -
-- 5. ADMINS
-- -
INSERT INTO admin_role (role_name) VALUES
  ('SUPER_ADMIN'),
  ('OPS_ADMIN'),
  ('COMPLIANCE_ADMIN'),
  ('RISK_ADMIN'),
  ('TRADE_ADMIN');

-- -
-- 5b. ADMINS  (role_ids: 1=SUPER, 2=OPS, 3=COMPLIANCE, 4=RISK, 5=TRADE)
-- -
INSERT INTO admin (event, email, password_hash, status, role_id) VALUES
  ('SYSTEM_INIT',  'superadmin@platform.com', SHA2('superpass!1', 256), 'ACTIVE', 1),
  ('ONBOARDING',   'ops1@platform.com',        SHA2('opspass!2',   256), 'ACTIVE', 2),
  ('KYC_REVIEW',   'compliance@platform.com',  SHA2('comppass!3',  256), 'ACTIVE', 3),
  ('RISK_CONTROL', 'risk@platform.com',         SHA2('riskpass!4',  256), 'ACTIVE', 4),
  ('TRADE_OPS',    'tradeops@platform.com',     SHA2('tradepass!5', 256), 'ACTIVE', 5);

-- -
-- 6. INVESTMENT ACCOUNTS
-- -
INSERT INTO investment_account (customer_id, broker_number, status, opened_at) VALUES
  (1,  'BRK-00001', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 2 YEAR)),
  (2,  'BRK-00002', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 18 MONTH)),
  (3,  'BRK-00003', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 1 YEAR)),
  (4,  'BRK-00004', 'SUSPENDED', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
  (5,  'BRK-00005', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  (6,  'BRK-00006', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 14 MONTH)),
  (7,  'BRK-00007', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 3 YEAR)),
  (8,  'BRK-00008', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 2 YEAR)),
  (10, 'BRK-00010', 'ACTIVE',    DATE_SUB(NOW(), INTERVAL 5 YEAR));

-- -
-- 7. BANK ACCOUNTS
-- -
INSERT INTO bank_account (customer_id, branch_id, account_number, account_type, status) VALUES
  (1,  1,  'ACC-1001', 'SAVINGS', 'ACTIVE'),
  (1,  1,  'ACC-1002', 'MARGIN',  'ACTIVE'),
  (2,  2,  'ACC-2001', 'SAVINGS', 'ACTIVE'),
  (3,  3,  'ACC-3001', 'CURRENT', 'ACTIVE'),
  (4,  4,  'ACC-4001', 'SAVINGS', 'ACTIVE'),
  (5,  5,  'ACC-5001', 'SAVINGS', 'ACTIVE'),
  (6,  6,  'ACC-6001', 'SAVINGS', 'ACTIVE'),
  (7,  7,  'ACC-7001', 'MARGIN',  'ACTIVE'),
  (8,  8,  'ACC-8001', 'CURRENT', 'ACTIVE'),
  (10, 10, 'ACC-0001', 'SAVINGS', 'ACTIVE');

-- -
-- 8. ACCOUNT BALANCES
-- -
INSERT INTO account_balance (bank_account_id, txn_total_balance, currency_code, available_balance, blocked_balance) VALUES
  (1,  250000.00, 'USD', 230000.00, 20000.00),
  (2,   50000.00, 'USD',  45000.00,  5000.00),
  (3,  180000.00, 'USD', 175000.00,  5000.00),
  (4,   75000.00, 'EUR',  70000.00,  5000.00),
  (5,   12000.00, 'USD',  12000.00,     0.00),
  (6,  320000.00, 'USD', 300000.00, 20000.00),
  (7,   95000.00, 'GBP',  90000.00,  5000.00),
  (8,  150000.00, 'USD', 140000.00, 10000.00),
  (9,  500000.00, 'INR', 500000.00,     0.00),
  (10, 800000.00, 'USD', 750000.00, 50000.00);

-- -
-- 9. STOCK PRICES
-- -
INSERT INTO stock_price (stock_id, price, currency_code, as_of_time) VALUES
  (1,  182.50, 'USD', DATE_SUB(NOW(), INTERVAL 1 DAY)),
  (1,  184.20, 'USD', NOW()),
  (2,  415.30, 'USD', DATE_SUB(NOW(), INTERVAL 1 DAY)),
  (2,  418.00, 'USD', NOW()),
  (3,  151.20, 'USD', DATE_SUB(NOW(), INTERVAL 1 DAY)),
  (3,  153.40, 'USD', NOW()),
  (4,  189.50, 'USD', DATE_SUB(NOW(), INTERVAL 1 DAY)),
  (4,  192.00, 'USD', NOW()),
  (5,  202.10, 'USD', DATE_SUB(NOW(), INTERVAL 1 DAY)),
  (5,  198.70, 'USD', NOW()),
  (6,  205.60, 'USD', NOW()),
  (7,  488.90, 'USD', NOW()),
  (8,  273.40, 'USD', NOW()),
  (9,  875.00, 'USD', NOW()),
  (10, 510.25, 'USD', NOW()),
  (11, 630.00, 'USD', NOW()),
  (12,  77.40, 'USD', NOW()),
  (13, 389.00, 'USD', NOW()),
  (14,  95.20, 'USD', NOW()),
  (15, 220.00, 'USD', NOW());

-- -
-- 10. PORTFOLIO HOLDINGS
-- -
INSERT INTO portfolio_holding (investment_account_id, stock_id, quantity, blocked_quantity, avg_buy_price) VALUES
  (1, 1,   50.000000, 0.000000, 160.000000),
  (1, 2,   20.000000, 0.000000, 380.000000),
  (1, 9,  100.000000, 5.000000, 420.000000),
  (2, 3,   30.000000, 0.000000, 135.000000),
  (2, 5,   15.000000, 0.000000, 185.000000),
  (3, 4,   10.000000, 0.000000, 170.000000),
  (3, 8,   25.000000, 5.000000, 255.000000),
  (5, 10,   8.000000, 0.000000, 480.000000),
  (6, 1,   80.000000, 0.000000, 155.000000),
  (6, 6,   40.000000, 0.000000, 190.000000),
  (7, 7,   12.000000, 2.000000, 450.000000),
  (8, 11,  22.000000, 0.000000, 580.000000),
  (9, 1,  120.000000, 0.000000, 145.000000);

-- -
-- 11. WATCHLISTS
-- -
INSERT INTO watchlist (customer_id, company_id_code) VALUES
  (1,  'GROUP-A'),
  (2,  'GROUP-B'),
  (3,  'GROUP-C'),
  (5,  'GROUP-D'),
  (10, 'GROUP-E');

INSERT INTO watchlist_item (watchlist_id, stock_id) VALUES
  (1, 3), (1, 4), (1, 5), (1, 10),
  (2, 1), (2, 9), (2, 11),
  (3, 2), (3, 6), (3, 7),
  (4, 8), (4, 12),
  (5, 1), (5, 2), (5, 9), (5, 13);

-- -
-- 12. RISK PROFILES
-- -
INSERT INTO risk_profile (customer_id, profile_name, max_order_value) VALUES
  (1,  'AGGRESSIVE',    500000.00),
  (2,  'MODERATE',      200000.00),
  (3,  'CONSERVATIVE',   50000.00),
  (5,  'MODERATE',      100000.00),
  (6,  'AGGRESSIVE',    750000.00),
  (7,  'MODERATE',      250000.00),
  (8,  'CONSERVATIVE',   80000.00),
  (10, 'AGGRESSIVE',   1000000.00);

-- -
-- 13. DAILY LIMIT USAGE
-- -
INSERT INTO daily_limit_usage (customer_id, usage_date, trades_count, trades_value, gross_traded_value, risk_level) VALUES
  (1,  CURDATE(),                        5,  45000.00,  46500.00, 2.50),
  (1,  DATE_SUB(NOW(), INTERVAL 1 DAY),  8,  62000.00,  64000.00, 3.10),
  (2,  CURDATE(),                          3,  18000.00,  18500.00, 1.80),
  (3,  CURDATE(),                          1,   5000.00,   5100.00, 0.90),
  (5,  CURDATE(),                          2,  10000.00,  10200.00, 1.20),
  (6,  CURDATE(),                         10,  95000.00, 100000.00, 4.00),
  (7,  CURDATE(),                          4,  22000.00,  22800.00, 2.00),
  (10, CURDATE(),                         12, 250000.00, 258000.00, 5.50);

-- -
-- 14. ADMIN RISK MAP
-- -
INSERT INTO admin_role_map (admin_id, entity_type, entity_id) VALUES
  (4, 'CUSTOMER',           1),
  (4, 'CUSTOMER',           2),
  (4, 'INVESTMENT_ACCOUNT', 1),
  (3, 'CUSTOMER',           9);

-- -
-- 15. AUDIT LOG
-- -
INSERT INTO audit_log (customer_id, stock_id, action, entity_type, entity_id, role_value, new_value, source_time) VALUES
  (1,  NULL, 'KYC_VERIFIED',      'CUSTOMER',            1,  'COMPLIANCE', 'VERIFIED',   DATE_SUB(NOW(), INTERVAL 2 YEAR)),
  (9,  NULL, 'KYC_REJECTED',      'CUSTOMER',            9,  'COMPLIANCE', 'REJECTED',   DATE_SUB(NOW(), INTERVAL 3 MONTH)),
  (1,  1,    'PORTFOLIO_BUY',     'PORTFOLIO_HOLDING',   1,  'TRADE_OPS',  '50 shares',  DATE_SUB(NOW(), INTERVAL 1 YEAR)),
  (6,  6,    'PORTFOLIO_BUY',     'PORTFOLIO_HOLDING',  11,  'TRADE_OPS',  '40 shares',  DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  (4,  NULL, 'ACCOUNT_SUSPENDED', 'INVESTMENT_ACCOUNT',  4,  'RISK_ADMIN', 'SUSPENDED',  DATE_SUB(NOW(), INTERVAL 4 MONTH));

-- -
-- 16. PRICE ALERTS
-- -
INSERT INTO price_alert (customer_id, stock_id, `condition`, trigger_price, is_active) VALUES
  (1,  1,  'ABOVE', 200.00, 1),
  (1,  9,  'ABOVE', 900.00, 1),
  (2,  5,  'BELOW', 180.00, 1),
  (3,  4,  'ABOVE', 210.00, 1),
  (5,  10, 'BELOW', 490.00, 1),
  (6,  1,  'ABOVE', 195.00, 0),
  (10, 2,  'ABOVE', 450.00, 1),
  (10, 9,  'ABOVE', 950.00, 1);

-- -
-- 17. CORPORATE ACTIONS
-- -
INSERT INTO corporate_action (investment_account_id, stock_id, action_type, ex_allot, record_date, pay_date, dividend_per_share) VALUES
  (1, 1, 'DIVIDEND',    NULL, '2025-11-14', '2025-11-28', 0.96),
  (1, 2, 'DIVIDEND',    NULL, '2025-12-05', '2025-12-19', 0.75),
  (3, 4, 'DIVIDEND',    NULL, '2025-10-10', '2025-10-24', 1.10),
  (6, 6, 'STOCK_SPLIT', 2.0,  '2025-09-01', '2025-09-15', NULL),
  (9, 1, 'DIVIDEND',    NULL, '2025-11-14', '2025-11-28', 0.96);

-- -
-- 18. FEE RULES
-- -
INSERT INTO fee_rule (investment_account_id, fee_type, rate, min_fee, max_fee, effective_from, is_active) VALUES
  (1, 'BROKERAGE', 0.001500,  1.00, 50.00, '2024-01-01', 1),
  (2, 'BROKERAGE', 0.001000,  1.00, 40.00, '2024-01-01', 1),
  (3, 'BROKERAGE', 0.002000,  1.50, 60.00, '2024-01-01', 1),
  (5, 'BROKERAGE', 0.001200,  1.00, 45.00, '2024-01-01', 1),
  (6, 'BROKERAGE', 0.000800,  0.50, 30.00, '2024-01-01', 1),
  (7, 'BROKERAGE', 0.001000,  1.00, 40.00, '2024-01-01', 1),
  (8, 'BROKERAGE', 0.001500,  1.00, 50.00, '2024-01-01', 1),
  (9, 'BROKERAGE', 0.001000,  1.00, 40.00, '2024-01-01', 1),
  (1, 'STT',       0.000100,  0.10, NULL,  '2024-01-01', 1),
  (2, 'STT',       0.000100,  0.10, NULL,  '2024-01-01', 1);

-- -
-- 19. CARDS
-- -
INSERT INTO card (customer_id, card_type, currency_code, description, issued_at, issued_by, effective_from, expiry_date, status) VALUES
  (1,  'DEBIT',   'USD', 'Primary USD debit card', DATE_SUB(NOW(), INTERVAL 2 YEAR),    2, '2022-01-01', '2027-01-01', 'ACTIVE'),
  (2,  'CREDIT',  'USD', 'Premium credit card',    DATE_SUB(NOW(), INTERVAL 18 MONTH),  2, '2022-07-01', '2027-07-01', 'ACTIVE'),
  (3,  'DEBIT',   'EUR', 'EUR debit card',          DATE_SUB(NOW(), INTERVAL 1 YEAR),    2, '2023-01-01', '2028-01-01', 'ACTIVE'),
  (5,  'PREPAID', 'USD', 'Trading prepaid card',   DATE_SUB(NOW(), INTERVAL 8 MONTH),   2, '2023-05-01', '2026-05-01', 'ACTIVE'),
  (6,  'CREDIT',  'USD', 'Platinum credit card',   DATE_SUB(NOW(), INTERVAL 14 MONTH),  2, '2022-11-01', '2027-11-01', 'ACTIVE'),
  (7,  'DEBIT',   'GBP', 'GBP debit card',          DATE_SUB(NOW(), INTERVAL 3 YEAR),    2, '2021-01-01', '2026-01-01', 'ACTIVE'),
  (8,  'DEBIT',   'INR', 'INR debit card',          DATE_SUB(NOW(), INTERVAL 2 YEAR),    2, '2022-01-01', '2027-01-01', 'ACTIVE'),
  (10, 'CREDIT',  'USD', 'Black card',              DATE_SUB(NOW(), INTERVAL 5 YEAR),    2, '2019-01-01', '2026-01-01', 'ACTIVE');

INSERT INTO card_limit (card_id, direction, float_amount, maximum) VALUES
  (1, 'OUT',   5000.00,  10000.00),
  (1, 'IN',    5000.00,  50000.00),
  (2, 'OUT',  20000.00,  50000.00),
  (2, 'IN',    5000.00,  50000.00),
  (3, 'OUT',   3000.00,   8000.00),
  (4, 'OUT',   1000.00,   5000.00),
  (5, 'OUT',  50000.00, 100000.00),
  (6, 'OUT',   5000.00,  20000.00),
  (8, 'OUT', 100000.00, 500000.00);

INSERT INTO fx_policy (card_id, direction, fx_markup_percent, class_source) VALUES
  (1, 'OUT', 0.015000, 'TIER1'),
  (2, 'OUT', 0.010000, 'PREMIUM'),
  (3, 'OUT', 0.015000, 'TIER1'),
  (5, 'OUT', 0.020000, 'STANDARD'),
  (8, 'OUT', 0.005000, 'BLACK');

-- -
-- 20. BANK TRANSACTIONS
-- -
INSERT INTO bank_txn (bank_account_id, txn_type, direction, amount, currency_code, txn_time, description, reference_type) VALUES
  (1,  'CREDIT', 'IN',  250000.00, 'USD', DATE_SUB(NOW(), INTERVAL 2 YEAR),    'Initial deposit',    'DEPOSIT'),
  (1,  'DEBIT',  'OUT',  20000.00, 'USD', DATE_SUB(NOW(), INTERVAL 1 YEAR),    'Trade settlement',   'TRADE'),
  (1,  'CREDIT', 'IN',   18500.00, 'USD', DATE_SUB(NOW(), INTERVAL 11 MONTH),  'Trade proceeds',     'TRADE'),
  (3,  'CREDIT', 'IN',  180000.00, 'USD', DATE_SUB(NOW(), INTERVAL 18 MONTH),  'Initial deposit',    'DEPOSIT'),
  (3,  'DEBIT',  'OUT',   5000.00, 'USD', DATE_SUB(NOW(), INTERVAL 6 MONTH),   'Trade settlement',   'TRADE'),
  (6,  'CREDIT', 'IN',  320000.00, 'USD', DATE_SUB(NOW(), INTERVAL 14 MONTH),  'Initial deposit',    'DEPOSIT'),
  (6,  'DEBIT',  'OUT',  20000.00, 'USD', DATE_SUB(NOW(), INTERVAL 3 MONTH),   'Trade settlement',   'TRADE'),
  (10, 'CREDIT', 'IN',  800000.00, 'USD', DATE_SUB(NOW(), INTERVAL 5 YEAR),    'Initial deposit',    'DEPOSIT'),
  (10, 'DEBIT',  'OUT', 100000.00, 'USD', DATE_SUB(NOW(), INTERVAL 1 YEAR),    'Large trade settle', 'TRADE');

-- -
-- 21. ORDERS
-- -
INSERT INTO orders (order_ref_id, investment_account_id, stock_id, order_type, quantity, limit_price, side, currency_code, payment_method, card_id, reserved_amount, status, created_at) VALUES
  ('ORD-001', 1,  1,  'LIMIT',  50.0, 162.00, 'BUY',  'USD', 'BANK', NULL,  8100.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 1 YEAR)),
  ('ORD-002', 1,  2,  'LIMIT',  20.0, 385.00, 'BUY',  'USD', 'BANK', NULL,  7700.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 10 MONTH)),
  ('ORD-003', 1,  9,  'MARKET',100.0,   NULL, 'BUY',  'USD', 'BANK', NULL, 43000.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  ('ORD-004', 2,  3,  'LIMIT',  30.0, 137.00, 'BUY',  'USD', 'BANK', NULL,  4110.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 9 MONTH)),
  ('ORD-005', 2,  5,  'MARKET', 15.0,   NULL, 'BUY',  'USD', 'CARD',    2,  2850.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 7 MONTH)),
  ('ORD-006', 3,  4,  'LIMIT',  10.0, 172.00, 'BUY',  'USD', 'BANK', NULL,  1720.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  ('ORD-007', 3,  8,  'LIMIT',  25.0, 257.00, 'BUY',  'USD', 'BANK', NULL,  6425.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 5 MONTH)),
  ('ORD-008', 5,  10, 'MARKET',  8.0,   NULL, 'BUY',  'USD', 'CARD',    4,  3900.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 4 MONTH)),
  ('ORD-009', 6,  1,  'LIMIT',  80.0, 157.00, 'BUY',  'USD', 'BANK', NULL, 12560.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 11 MONTH)),
  ('ORD-010', 6,  6,  'MARKET', 40.0,   NULL, 'BUY',  'USD', 'BANK', NULL,  7800.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 3 MONTH)),
  ('ORD-011', 7,  7,  'LIMIT',  12.0, 452.00, 'BUY',  'USD', 'BANK', NULL,  5424.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  ('ORD-012', 8,  11, 'LIMIT',  22.0, 585.00, 'BUY',  'USD', 'BANK', NULL, 12870.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  ('ORD-013', 9,  1,  'LIMIT', 120.0, 147.00, 'BUY',  'USD', 'BANK', NULL, 17640.00, 'FILLED',  DATE_SUB(NOW(), INTERVAL 2 YEAR)),
  ('ORD-014', 1,  1,  'LIMIT',  10.0, 183.00, 'SELL', 'USD', 'BANK', NULL,     NULL, 'OPEN',    DATE_SUB(NOW(), INTERVAL 1 HOUR)),
  ('ORD-015', 6,  1,  'MARKET', 20.0,   NULL, 'BUY',  'USD', 'CARD',    5,  3680.00, 'PENDING', DATE_SUB(NOW(), INTERVAL 10 MINUTE));

-- -
-- 22. ORDER FILLS
-- -
INSERT INTO order_fill (order_id, filled_qty, fill_price, currency_code, fill_time) VALUES
  (1,   50.0, 161.50, 'USD', DATE_SUB(NOW(), INTERVAL 1 YEAR)),
  (2,   20.0, 384.00, 'USD', DATE_SUB(NOW(), INTERVAL 10 MONTH)),
  (3,  100.0, 425.00, 'USD', DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  (4,   30.0, 136.00, 'USD', DATE_SUB(NOW(), INTERVAL 9 MONTH)),
  (5,   15.0, 186.50, 'USD', DATE_SUB(NOW(), INTERVAL 7 MONTH)),
  (6,   10.0, 171.00, 'USD', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  (7,   25.0, 256.00, 'USD', DATE_SUB(NOW(), INTERVAL 5 MONTH)),
  (8,    8.0, 482.00, 'USD', DATE_SUB(NOW(), INTERVAL 4 MONTH)),
  (9,   80.0, 156.00, 'USD', DATE_SUB(NOW(), INTERVAL 11 MONTH)),
  (10,  40.0, 192.00, 'USD', DATE_SUB(NOW(), INTERVAL 3 MONTH)),
  (11,  12.0, 451.00, 'USD', DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  (12,  22.0, 584.00, 'USD', DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  (13, 120.0, 146.00, 'USD', DATE_SUB(NOW(), INTERVAL 2 YEAR));

-- -
-- 23. TRADES
-- -
INSERT INTO trade (fill_id, order_id, stock_id, side, quantity, price, currency_code, gross_value, trade_time) VALUES
  (1,  1,  1,  'BUY',  50.0, 161.50, 'USD',  8075.00, DATE_SUB(NOW(), INTERVAL 1 YEAR)),
  (2,  2,  2,  'BUY',  20.0, 384.00, 'USD',  7680.00, DATE_SUB(NOW(), INTERVAL 10 MONTH)),
  (3,  3,  9,  'BUY', 100.0, 425.00, 'USD', 42500.00, DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  (4,  4,  3,  'BUY',  30.0, 136.00, 'USD',  4080.00, DATE_SUB(NOW(), INTERVAL 9 MONTH)),
  (5,  5,  5,  'BUY',  15.0, 186.50, 'USD',  2797.50, DATE_SUB(NOW(), INTERVAL 7 MONTH)),
  (6,  6,  4,  'BUY',  10.0, 171.00, 'USD',  1710.00, DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  (7,  7,  8,  'BUY',  25.0, 256.00, 'USD',  6400.00, DATE_SUB(NOW(), INTERVAL 5 MONTH)),
  (8,  8,  10, 'BUY',   8.0, 482.00, 'USD',  3856.00, DATE_SUB(NOW(), INTERVAL 4 MONTH)),
  (9,  9,  1,  'BUY',  80.0, 156.00, 'USD', 12480.00, DATE_SUB(NOW(), INTERVAL 11 MONTH)),
  (10, 10, 6,  'BUY',  40.0, 192.00, 'USD',  7680.00, DATE_SUB(NOW(), INTERVAL 3 MONTH)),
  (11, 11, 7,  'BUY',  12.0, 451.00, 'USD',  5412.00, DATE_SUB(NOW(), INTERVAL 8 MONTH)),
  (12, 12, 11, 'BUY',  22.0, 584.00, 'USD', 12848.00, DATE_SUB(NOW(), INTERVAL 6 MONTH)),
  (13, 13, 1,  'BUY', 120.0, 146.00, 'USD', 17520.00, DATE_SUB(NOW(), INTERVAL 2 YEAR));

-- -
-- 24. TRADE CHARGES
-- -
INSERT INTO trade_charge (trade_id, fee_rule_id, available_limit, free_type, amount) VALUES
  (1,  1, 50.00, 'BROKERAGE', 12.11),
  (2,  1, 50.00, 'BROKERAGE', 11.52),
  (3,  1, 50.00, 'BROKERAGE', 50.00),
  (4,  2, 40.00, 'BROKERAGE',  4.08),
  (5,  2, 40.00, 'BROKERAGE',  2.80),
  (6,  3, 60.00, 'BROKERAGE',  3.42),
  (7,  3, 60.00, 'BROKERAGE',  9.60),
  (8,  5, 30.00, 'BROKERAGE',  3.08),
  (9,  6, 30.00, 'BROKERAGE',  9.98),
  (10, 6, 30.00, 'BROKERAGE',  6.14),
  (11, 7, 40.00, 'BROKERAGE',  5.41),
  (12, 8, 40.00, 'BROKERAGE', 12.85),
  (13, 9, 40.00, 'BROKERAGE', 17.52);

-- -
-- 25. TRADE PAYMENTS
-- -
INSERT INTO trade_payment (order_id, trade_id, buy_trade_id, status, payment_method) VALUES
  (1,  1,  1,  'COMPLETED', 'BANK_TRANSFER'),
  (2,  2,  2,  'COMPLETED', 'BANK_TRANSFER'),
  (3,  3,  3,  'COMPLETED', 'BANK_TRANSFER'),
  (4,  4,  4,  'COMPLETED', 'BANK_TRANSFER'),
  (5,  5,  5,  'COMPLETED', 'CARD'),
  (6,  6,  6,  'COMPLETED', 'BANK_TRANSFER'),
  (7,  7,  7,  'COMPLETED', 'BANK_TRANSFER'),
  (8,  8,  8,  'COMPLETED', 'CARD'),
  (9,  9,  9,  'COMPLETED', 'BANK_TRANSFER'),
  (10, 10, 10, 'COMPLETED', 'BANK_TRANSFER'),
  (11, 11, 11, 'COMPLETED', 'BANK_TRANSFER'),
  (12, 12, 12, 'COMPLETED', 'BANK_TRANSFER'),
  (13, 13, 13, 'COMPLETED', 'BANK_TRANSFER');

-- -
-- 26. SETTLEMENTS
-- -
INSERT INTO settlement (trade_id, investment_account_id, currency_code, scheduled_date, settled_at, status, payment_method) VALUES
  (1,  1, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 363 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 361 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (2,  1, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 298 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 296 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (3,  1, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 238 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 236 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (4,  2, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 268 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 266 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (5,  2, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 208 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 206 DAY), 'SETTLED', 'CARD'),
  (6,  3, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 178 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 176 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (7,  3, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 148 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 146 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (8,  5, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 118 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 116 DAY), 'SETTLED', 'CARD'),
  (9,  6, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 328 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 326 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (10, 6, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL  88 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL  86 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (11, 7, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 238 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 236 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (12, 8, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 178 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 176 DAY), 'SETTLED', 'BANK_TRANSFER'),
  (13, 9, 'USD', DATE_ADD(DATE(DATE_SUB(NOW(), INTERVAL 728 DAY)), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 726 DAY), 'SETTLED', 'BANK_TRANSFER');

-- -
-- 27. HOLDING LOTS
-- Columns: settlement_id, investment_account_id, stock_id, status,
--          quantity, remaining_qty, buy_price, acquired_at
-- quantity/remaining_qty/buy_price/acquired_at sourced directly from
-- the linked trade row (via settlement → trade).
-- All seed lots are OPEN (no sells have been processed yet).
-- -
INSERT INTO holding_lot
    (settlement_id, investment_account_id, stock_id, status,
     quantity, remaining_qty, buy_price, acquired_at)
VALUES
--  se  inv  stk  status     qty    rem_qty  buy_price  acquired_at
  (1,  1,  1,  'OPEN',   50.0,   50.0,  161.50, DATE_SUB(NOW(), INTERVAL 1 YEAR)),    -- Alice:  50 AAPL  @ 161.50
  (2,  1,  2,  'OPEN',   20.0,   20.0,  384.00, DATE_SUB(NOW(), INTERVAL 10 MONTH)),  -- Alice:  20 MSFT  @ 384.00
  (3,  1,  9,  'OPEN',  100.0,  100.0,  425.00, DATE_SUB(NOW(), INTERVAL 8 MONTH)),   -- Alice: 100 NVDA  @ 425.00
  (4,  2,  3,  'OPEN',   30.0,   30.0,  136.00, DATE_SUB(NOW(), INTERVAL 9 MONTH)),   -- Bob:    30 GOOGL @ 136.00
  (5,  2,  5,  'OPEN',   15.0,   15.0,  186.50, DATE_SUB(NOW(), INTERVAL 7 MONTH)),   -- Bob:    15 TSLA  @ 186.50
  (6,  3,  4,  'OPEN',   10.0,   10.0,  171.00, DATE_SUB(NOW(), INTERVAL 6 MONTH)),   -- Carol:  10 AMZN  @ 171.00
  (7,  3,  8,  'OPEN',   25.0,   25.0,  256.00, DATE_SUB(NOW(), INTERVAL 5 MONTH)),   -- Carol:  25 V     @ 256.00
  (8,  5,  10, 'OPEN',    8.0,    8.0,  482.00, DATE_SUB(NOW(), INTERVAL 4 MONTH)),   -- Eva:     8 META  @ 482.00
  (9,  6,  1,  'OPEN',   80.0,   80.0,  156.00, DATE_SUB(NOW(), INTERVAL 11 MONTH)),  -- Frank:  80 AAPL  @ 156.00
  (10, 6,  6,  'OPEN',   40.0,   40.0,  192.00, DATE_SUB(NOW(), INTERVAL 3 MONTH)),   -- Frank:  40 JPM   @ 192.00
  (11, 7,  7,  'OPEN',   12.0,   12.0,  451.00, DATE_SUB(NOW(), INTERVAL 8 MONTH)),   -- Grace:  12 GS    @ 451.00
  (12, 8,  11, 'OPEN',   22.0,   22.0,  584.00, DATE_SUB(NOW(), INTERVAL 6 MONTH)),   -- Henry:  22 NFLX  @ 584.00
  (13, 9,  1,  'OPEN',  120.0,  120.0,  146.00, DATE_SUB(NOW(), INTERVAL 2 YEAR));    -- James: 120 AAPL  @ 146.00

-- -
-- 28. CREDIT CARD DETAILS
-- -
INSERT INTO credit_card_details (card_id, trade_id, available_limit, free_type_bl, used_amount) VALUES
  (2, 5,  48000.00, 2000.00,  2797.50),
  (5, 10, 97000.00, 3000.00,  7680.00),
  (8, 13,495000.00, 5000.00, 17520.00);
  
-- -
-- 29. EXCHANGE RATES
-- -
INSERT INTO exchange_rate 
    (base_currency, quote_currency, rate, bank_fx_markup_percent) 
VALUES
-- same-currency rows: no conversion, no markup
('USD', 'USD', 1.000000, 0.000000),
('EUR', 'EUR', 1.000000, 0.000000),
('GBP', 'GBP', 1.000000, 0.000000),
('INR', 'INR', 1.000000, 0.000000),
-- cross-currency rows
('USD', 'EUR', 0.921000, 0.010000),  -- 1 USD = 0.921 EUR, 1% bank markup
('EUR', 'USD', 1.086000, 0.010000),  -- 1 EUR = 1.086 USD
('USD', 'GBP', 0.791000, 0.012000),
('GBP', 'USD', 1.264000, 0.012000),
('USD', 'INR', 83.500000, 0.005000),
('INR', 'USD', 0.011976, 0.005000),
('EUR', 'GBP', 0.857000, 0.012000),
('GBP', 'EUR', 1.167000, 0.012000);

SET FOREIGN_KEY_CHECKS = 1;