SET GLOBAL event_scheduler = ON;
SELECT event_name, status, last_executed, starts
FROM information_schema.EVENTS
WHERE event_name = 'evt_settle_pending_trades';
CALL settle_now();