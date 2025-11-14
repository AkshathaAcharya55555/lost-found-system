-- ========================================
-- SERVER-SIDE SQL OPERATIONS
-- Lost & Found Management System
-- Database: SQLite
-- ========================================
-- This file contains SQL queries executed by the server
-- to handle API requests and business logic
-- ========================================

-- ========================================
-- 1. CONNECTION AND INITIALIZATION
-- ========================================

-- Connect to database
-- Implementation: sqlite3.connect('lostandfound.db')

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Set journal mode for better concurrency
PRAGMA journal_mode = WAL;

-- Optimize performance
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 10000;
PRAGMA temp_store = MEMORY;


-- ========================================
-- 2. API ENDPOINT QUERIES
-- ========================================

-- ----------------------------------------
-- QUERY 1: Get All Unclaimed Items
-- Endpoint: GET /api/items
-- Purpose: Public item search
-- ----------------------------------------
SELECT 
    id,
    name,
    category,
    description,
    color,
    dateFound,
    foundAt,
    (julianday('now') - julianday(dateFound)) as DaysUnclaimed
FROM Items
WHERE isClaimed = 0
ORDER BY dateFound DESC;


-- ----------------------------------------
-- QUERY 2: Get Pending Claims with JOIN
-- Endpoint: GET /api/claims
-- Purpose: Admin panel - pending claims review
-- Features: Multi-table JOIN (3 tables)
-- ----------------------------------------
SELECT 
    c.id as claimID,
    c.claimDate,
    c.verificationCode,
    c.ownerFirstName as OwnerFirstName,
    c.ownerLastName as OwnerLastName,
    i.name as itemName,
    i.category as itemCategory,
    i.foundAt as FoundAtLocation,
    COALESCE(e.firstName || ' ' || e.lastName, 'Unassigned') as ManagingStaff
FROM Claims c
INNER JOIN Items i ON c.itemID = i.id
LEFT JOIN Employees e ON c.handledBy = e.id
WHERE c.verificationStatus = 'Pending'
ORDER BY c.claimDate DESC;


-- ----------------------------------------
-- QUERY 3: Insert New Found Item
-- Endpoint: POST /api/items
-- Purpose: Add item to database
-- Security: Uses parameterized query (? placeholders)
-- ----------------------------------------
INSERT INTO Items (name, category, description, color, dateFound, foundAt, isClaimed)
VALUES (?, ?, ?, ?, date('now'), ?, 0);

-- Get the auto-generated ID of inserted item
SELECT last_insert_rowid() as newItemID;


-- ----------------------------------------
-- QUERY 4: Dashboard Metrics (Aggregates)
-- Endpoint: GET /api/metrics
-- Purpose: Statistics for admin dashboard
-- Features: COUNT, AVG, CASE
-- ----------------------------------------

-- Unclaimed items count and average days
SELECT 
    COUNT(*) as totalUnclaimed,
    AVG(julianday('now') - julianday(dateFound)) as avgDaysUnclaimed
FROM Items
WHERE isClaimed = 0;

-- Claimed items count
SELECT COUNT(*) as totalClaimed
FROM Items
WHERE isClaimed = 1;

-- Total items
SELECT COUNT(*) as totalItems
FROM Items;

-- Pending claims count
SELECT COUNT(*) as pendingClaims
FROM Claims
WHERE verificationStatus = 'Pending';

-- Approved claims count
SELECT COUNT(*) as approvedClaims
FROM Claims
WHERE verificationStatus = 'Approved';


-- ----------------------------------------
-- QUERY 5: Get Employee List
-- Endpoint: GET /api/employees
-- Purpose: Staff performance view
-- ----------------------------------------
SELECT 
    id as employeeID,
    firstName,
    lastName,
    position,
    itemsManaged
FROM Employees
ORDER BY itemsManaged DESC;


-- ========================================
-- 3. TRANSACTION: APPROVE CLAIM
-- ========================================
-- Endpoint: POST /api/claims/:id/approve
-- Purpose: Approve ownership claim
-- Features: Multi-step transaction, ACID compliance
-- Triggered by: "Approve Claim" button in Admin Panel
-- ========================================
-- 
-- BUTTON WORKFLOW:
-- 1. User clicks green "Approve Claim" button (ui.html line 517)
-- 2. JavaScript function approveClaim() called (ui.html line 430)
-- 3. Sends POST request to /api/claims/:id/approve
-- 4. Python backend executes this transaction (server.py line 201-251)
-- 5. Database updates 3 tables atomically
-- 6. UI refreshes and shows success message
-- ========================================

-- Step 1: Begin transaction
BEGIN TRANSACTION;

-- Step 2: Verify claim exists and is pending
SELECT itemID 
FROM Claims 
WHERE id = ? AND verificationStatus = 'Pending';
-- If no result, ROLLBACK and return error

-- Step 3: Update claim status to Approved
UPDATE Claims 
SET verificationStatus = 'Approved' 
WHERE id = ?;

-- Step 4: Mark item as claimed
-- ⚡ This UPDATE triggers trg_Item_BeforeUpdate
-- ⚡ which auto-sets dateUpdated = datetime('now')
UPDATE Items 
SET isClaimed = 1 
WHERE id = ?;

-- Step 5: Log status change in history
INSERT INTO ItemStatus (itemID, status, statusDate)
VALUES (?, 'Claimed', datetime('now'));

-- Step 6: Commit transaction (all or nothing)
COMMIT;
-- If any error occurs: ROLLBACK;

-- ========================================
-- APPROVE BUTTON - COMPLETE IMPLEMENTATION
-- ========================================
-- This section documents how the "Approve Claim" button
-- connects frontend (HTML/JS) to backend (Python) to database (SQL)
-- ========================================

-- FRONTEND (ui.html):
-- ----------------------------------------
-- Line 517-519: Create button with onclick handler
--   button.textContent = 'Approve Claim';
--   button.className = 'bg-green-600 text-white...';
--   button.onclick = () => approveClaim(claim.claimID);

-- Line 430-442: JavaScript function that sends API request
--   async function approveClaim(claimID) {
--       const res = await fetch(`/api/claims/${claimID}/approve`, { method: 'POST' });
--       await fetchPendingClaims();  // Refresh list
--       showModal('Claim Approved', `Claim ID ${claimID} approved`);
--   }

-- BACKEND (server.py):
-- ----------------------------------------
-- Line 201-251: Python function that executes transaction
--   def approve_claim(self, claim_id):
--       conn.execute('BEGIN TRANSACTION')
--       # Execute the SQL queries documented above (lines 148-167)
--       conn.commit()

-- DATABASE OPERATIONS (Executed above):
-- ----------------------------------------
-- 1. SELECT to verify claim exists (line 150)
-- 2. UPDATE Claims table (line 155)
-- 3. UPDATE Items table (line 160) - TRIGGERS trg_Item_BeforeUpdate!
-- 4. INSERT into ItemStatus (line 165)
-- 5. COMMIT all changes (line 169)

-- TRIGGER ACTIVATION:
-- ----------------------------------------
-- When UPDATE Items executes (step 3 above), the trigger fires:
--   CREATE TRIGGER trg_Item_BeforeUpdate
--   AFTER UPDATE ON Items
--   FOR EACH ROW
--   BEGIN
--       UPDATE Items SET dateUpdated = datetime('now') WHERE id = NEW.id;
--   END;
-- This automatically updates the timestamp without manual code!

-- ACID PROPERTIES DEMONSTRATED:
-- ----------------------------------------
-- ATOMICITY: All 4 operations succeed or all fail (BEGIN/COMMIT/ROLLBACK)
-- CONSISTENCY: Foreign keys and constraints ensure valid data
-- ISOLATION: Transaction locks prevent concurrent conflicts
-- DURABILITY: Committed changes persist to disk (lostandfound.db)

-- DATA FLOW SUMMARY:
-- ----------------------------------------
-- User Action → HTML Button → JavaScript fetch() → 
-- HTTP POST → Python API → SQL Transaction → 
-- Database Update (3 tables) → Trigger Fires → 
-- Response → UI Refresh → Success Modal
-- ========================================


-- ========================================
-- 4. DATA VALIDATION QUERIES
-- ========================================

-- Check if item exists and is unclaimed
SELECT COUNT(*) as itemExists
FROM Items
WHERE id = ? AND isClaimed = 0;

-- Check if claim already exists for item
SELECT COUNT(*) as claimExists
FROM Claims
WHERE itemID = ? AND verificationStatus = 'Pending';

-- Verify employee exists
SELECT COUNT(*) as employeeExists
FROM Employees
WHERE id = ?;

-- Get item details by ID
SELECT 
    id,
    name,
    category,
    description,
    color,
    dateFound,
    foundAt,
    isClaimed,
    dateUpdated
FROM Items
WHERE id = ?;


-- ========================================
-- 5. SEARCH AND FILTER QUERIES
-- ========================================

-- Search items by category
SELECT * FROM Items
WHERE category = ? AND isClaimed = 0
ORDER BY dateFound DESC;

-- Search items by color
SELECT * FROM Items
WHERE LOWER(color) LIKE LOWER(?) AND isClaimed = 0
ORDER BY dateFound DESC;

-- Search items by location
SELECT * FROM Items
WHERE LOWER(foundAt) LIKE LOWER(?) AND isClaimed = 0
ORDER BY dateFound DESC;

-- Search items by date range
SELECT * FROM Items
WHERE dateFound BETWEEN ? AND ? 
AND isClaimed = 0
ORDER BY dateFound DESC;

-- Full-text search on item name and description
SELECT * FROM Items
WHERE (LOWER(name) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?))
AND isClaimed = 0
ORDER BY dateFound DESC;


-- ========================================
-- 6. REPORTING QUERIES
-- ========================================

-- Daily report: Items found per day
SELECT 
    dateFound,
    COUNT(*) as itemsFound,
    SUM(CASE WHEN isClaimed = 1 THEN 1 ELSE 0 END) as itemsClaimed
FROM Items
GROUP BY dateFound
ORDER BY dateFound DESC;

-- Category distribution
SELECT 
    category,
    COUNT(*) as totalItems,
    COUNT(CASE WHEN isClaimed = 0 THEN 1 END) as unclaimed,
    COUNT(CASE WHEN isClaimed = 1 THEN 1 END) as claimed
FROM Items
GROUP BY category
ORDER BY totalItems DESC;

-- Location statistics
SELECT 
    foundAt as location,
    COUNT(*) as itemsFound,
    AVG(julianday('now') - julianday(dateFound)) as avgDaysUnclaimed
FROM Items
WHERE isClaimed = 0
GROUP BY foundAt
ORDER BY itemsFound DESC;

-- Employee performance ranking
SELECT 
    e.id,
    e.firstName || ' ' || e.lastName as employeeName,
    e.position,
    e.itemsManaged,
    COUNT(c.id) as claimsHandled,
    SUM(CASE WHEN c.verificationStatus = 'Approved' THEN 1 ELSE 0 END) as approved,
    SUM(CASE WHEN c.verificationStatus = 'Pending' THEN 1 ELSE 0 END) as pending
FROM Employees e
LEFT JOIN Claims c ON e.id = c.handledBy
GROUP BY e.id, employeeName, e.position, e.itemsManaged
ORDER BY claimsHandled DESC;


-- ========================================
-- 7. UPDATE QUERIES
-- ========================================

-- Update item description
UPDATE Items
SET description = ?, dateUpdated = datetime('now')
WHERE id = ?;

-- Assign employee to claim
UPDATE Claims
SET handledBy = ?
WHERE id = ? AND verificationStatus = 'Pending';

-- Update employee items managed count
UPDATE Employees
SET itemsManaged = itemsManaged + 1
WHERE id = ?;

-- Reject a claim
UPDATE Claims
SET verificationStatus = 'Rejected'
WHERE id = ?;


-- ========================================
-- 8. DELETE QUERIES (Soft Delete Preferred)
-- ========================================

-- Mark item as deleted (soft delete)
UPDATE Items
SET isClaimed = 2  -- 0=unclaimed, 1=claimed, 2=deleted
WHERE id = ?;

-- Remove old pending claims (older than 30 days)
DELETE FROM Claims
WHERE verificationStatus = 'Pending' 
AND julianday('now') - julianday(claimDate) > 30;

-- Clean up item status history (older than 1 year)
DELETE FROM ItemStatus
WHERE julianday('now') - julianday(statusDate) > 365;


-- ========================================
-- 9. ADVANCED ANALYTICS QUERIES
-- ========================================

-- Items with multiple claims (potential disputes)
SELECT 
    i.id,
    i.name,
    i.category,
    COUNT(c.id) as claimCount,
    GROUP_CONCAT(c.ownerFirstName || ' ' || c.ownerLastName, ', ') as claimants
FROM Items i
INNER JOIN Claims c ON i.id = c.itemID
WHERE c.verificationStatus = 'Pending'
GROUP BY i.id, i.name, i.category
HAVING claimCount > 1
ORDER BY claimCount DESC;

-- Items unclaimed for over 30 days (need attention)
SELECT 
    id,
    name,
    category,
    foundAt,
    dateFound,
    julianday('now') - julianday(dateFound) as daysUnclaimed
FROM Items
WHERE isClaimed = 0 
AND julianday('now') - julianday(dateFound) > 30
ORDER BY daysUnclaimed DESC;

-- Monthly trend analysis
SELECT 
    strftime('%Y-%m', dateFound) as month,
    COUNT(*) as itemsFound,
    SUM(CASE WHEN isClaimed = 1 THEN 1 ELSE 0 END) as claimed,
    ROUND(100.0 * SUM(CASE WHEN isClaimed = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as claimRate
FROM Items
GROUP BY month
ORDER BY month DESC
LIMIT 12;


-- ========================================
-- 10. UTILITY QUERIES
-- ========================================

-- View database schema
SELECT name, sql 
FROM sqlite_master 
WHERE type='table'
ORDER BY name;

-- View all triggers
SELECT name, sql 
FROM sqlite_master 
WHERE type='trigger'
ORDER BY name;

-- View all indexes
SELECT name, sql 
FROM sqlite_master 
WHERE type='index'
ORDER BY name;

-- Database statistics
SELECT 
    (SELECT COUNT(*) FROM Items) as totalItems,
    (SELECT COUNT(*) FROM Claims) as totalClaims,
    (SELECT COUNT(*) FROM Employees) as totalEmployees,
    (SELECT COUNT(*) FROM ItemStatus) as statusRecords;

-- Check database integrity
PRAGMA integrity_check;

-- Get database size
SELECT page_count * page_size as dbSize 
FROM pragma_page_count(), pragma_page_size();


-- ========================================
-- 11. BACKUP AND MAINTENANCE QUERIES
-- ========================================

-- Vacuum database (optimize storage)
VACUUM;

-- Analyze tables for query optimization
ANALYZE;

-- Rebuild indexes
REINDEX;

-- Export data (for backup)
-- .mode csv
-- .output items_backup.csv
-- SELECT * FROM Items;


-- ========================================
-- 12. SECURITY AND ACCESS CONTROL
-- ========================================

-- Parameterized queries prevent SQL injection
-- Example: cursor.execute("SELECT * FROM Items WHERE id = ?", (item_id,))
-- Instead of: "SELECT * FROM Items WHERE id = " + item_id  (VULNERABLE!)

-- Input validation checks
-- Check ID is integer: CAST(? AS INTEGER)
-- Check text length: LENGTH(?) <= 255
-- Check date format: date(?) IS NOT NULL


-- ========================================
-- END OF SERVER SQL OPERATIONS
-- ========================================

-- NOTES:
-- 1. All queries use parameterized placeholders (?) for security
-- 2. Transactions ensure ACID compliance
-- 3. Indexes automatically created on primary and foreign keys
-- 4. Trigger trg_Item_BeforeUpdate handles timestamp updates
-- 5. Foreign key constraints enforce referential integrity
-- ========================================

-- ========================================
-- APPENDIX: APPROVE CLAIM BUTTON - VISUAL FLOW
-- ========================================
--
-- USER CLICKS "APPROVE CLAIM" BUTTON
--           |
--           v
-- ┌─────────────────────────────────────────────┐
-- │  ui.html (Line 519)                         │
-- │  button.onclick = () => approveClaim(2)     │
-- └─────────────────────────────────────────────┘
--           |
--           v
-- ┌─────────────────────────────────────────────┐
-- │  ui.html (Lines 430-442)                    │
-- │  async function approveClaim(claimID) {     │
-- │    fetch('/api/claims/2/approve', POST)     │
-- │  }                                          │
-- └─────────────────────────────────────────────┘
--           | HTTP POST Request
--           v
-- ┌─────────────────────────────────────────────┐
-- │  server.py (Lines 201-251)                  │
-- │  def approve_claim(self, claim_id):         │
-- │    Execute SQL queries from this file ────┐ │
-- └─────────────────────────────────────────────┘
--           |                                   |
--           v                                   |
-- ┌─────────────────────────────────────────────┐
-- │  THIS FILE: server_queries.sql              │<
-- │  Lines 148-169: Transaction                 │
-- │    BEGIN TRANSACTION                        │
-- │    SELECT itemID FROM Claims... (line 150)  │
-- │    UPDATE Claims... (line 155)              │
-- │    UPDATE Items... (line 160)               │
-- │    INSERT ItemStatus... (line 165)          │
-- │    COMMIT (line 169)                        │
-- └─────────────────────────────────────────────┘
--           |
--           v
-- ┌─────────────────────────────────────────────┐
-- │  SQLite Database (lostandfound.db)          │
-- │  Tables Updated:                            │
-- │  ✓ Claims.verificationStatus = 'Approved'   │
-- │  ✓ Items.isClaimed = 1                      │
-- │  ✓ Items.dateUpdated = now (by trigger!)    │
-- │  ✓ ItemStatus new record inserted           │
-- └─────────────────────────────────────────────┘
--           | Success Response
--           v
-- ┌─────────────────────────────────────────────┐
-- │  ui.html (Lines 437-439)                    │
-- │  - Refresh pending claims list              │
-- │  - Refresh unclaimed items list             │
-- │  - Show success modal to user               │
-- └─────────────────────────────────────────────┘
--           |
--           v
-- ┌─────────────────────────────────────────────┐
-- │  USER SEES:                                 │
-- │  ✅ "Claim Approved" success message         │
-- │  ✅ Claim removed from pending list          │
-- │  ✅ Item removed from public search          │
-- │  ✅ Dashboard metrics updated                │
-- └─────────────────────────────────────────────┘
--
-- KEY FILES INVOLVED:
-- 1. ui.html (lines 430-442, 517-519) - Frontend button and handler
-- 2. server.py (lines 201-251) - Backend API endpoint
-- 3. server_queries.sql (lines 148-169) - SQL transaction queries
-- 4. schema.sql (lines 57-62) - Database trigger
-- 5. lostandfound.db - SQLite database file
--
-- FOR VIVA DEMONSTRATION:
-- 1. Show the green "Approve Claim" button in browser
-- 2. Open browser DevTools → Network tab
-- 3. Click the button
-- 4. Show POST request to /api/claims/:id/approve
-- 5. Show server.py code executing the transaction
-- 6. Show this SQL file with the actual queries
-- 7. Run: SELECT * FROM Claims WHERE id = X; (before)
-- 8. Click approve button
-- 9. Run: SELECT * FROM Claims WHERE id = X; (after - status changed!)
-- 10. Show trigger fired: SELECT dateUpdated FROM Items WHERE id = X;
--
-- ========================================
-- END OF SERVER SQL OPERATIONS
-- ========================================
