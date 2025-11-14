-- ========================================
-- COMPLETE SQL DATABASE IMPLEMENTATION
-- Lost & Found Management System
-- Database: SQLite 3
-- Created: November 2025
-- ========================================

-- ========================================
-- SECTION 1: DATABASE CONFIGURATION
-- ========================================

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Set journal mode for better performance
PRAGMA journal_mode = WAL;

-- Configure synchronization
PRAGMA synchronous = NORMAL;

-- Set cache size (10MB)
PRAGMA cache_size = 10000;

-- ========================================
-- SECTION 2: TABLE DEFINITIONS
-- ========================================

-- Table 1: Items (All found items)
CREATE TABLE IF NOT EXISTS Items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    color TEXT,
    dateFound TEXT NOT NULL,
    foundAt TEXT NOT NULL,
    isClaimed INTEGER DEFAULT 0,
    dateUpdated TEXT DEFAULT (datetime('now')),
    CONSTRAINT chk_claimed CHECK (isClaimed IN (0, 1))
);

-- Table 2: Claims (Ownership claims)
CREATE TABLE IF NOT EXISTS Claims (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    claimDate TEXT NOT NULL,
    verificationCode TEXT,
    ownerFirstName TEXT NOT NULL,
    ownerLastName TEXT NOT NULL,
    itemID INTEGER NOT NULL,
    verificationStatus TEXT DEFAULT 'Pending',
    handledBy INTEGER,
    FOREIGN KEY (itemID) REFERENCES Items(id) ON DELETE CASCADE,
    FOREIGN KEY (handledBy) REFERENCES Employees(id) ON DELETE SET NULL,
    CONSTRAINT chk_status CHECK (verificationStatus IN ('Pending', 'Approved', 'Rejected'))
);

-- Table 3: Employees (Staff members)
CREATE TABLE IF NOT EXISTS Employees (
    id INTEGER PRIMARY KEY,
    firstName TEXT NOT NULL,
    lastName TEXT NOT NULL,
    position TEXT,
    itemsManaged INTEGER DEFAULT 0,
    CONSTRAINT chk_items_managed CHECK (itemsManaged >= 0)
);

-- Table 4: ItemStatus (Status history)
CREATE TABLE IF NOT EXISTS ItemStatus (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    itemID INTEGER NOT NULL,
    status TEXT NOT NULL,
    statusDate TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (itemID) REFERENCES Items(id) ON DELETE CASCADE
);

-- ========================================
-- SECTION 3: INDEXES FOR PERFORMANCE
-- ========================================

-- Index on Items.category for faster filtering
CREATE INDEX IF NOT EXISTS idx_items_category ON Items(category);

-- Index on Items.isClaimed for faster unclaimed queries
CREATE INDEX IF NOT EXISTS idx_items_claimed ON Items(isClaimed);

-- Index on Items.dateFound for sorting
CREATE INDEX IF NOT EXISTS idx_items_date ON Items(dateFound);

-- Index on Claims.verificationStatus for pending queries
CREATE INDEX IF NOT EXISTS idx_claims_status ON Claims(verificationStatus);

-- Index on Claims.itemID for JOIN performance
CREATE INDEX IF NOT EXISTS idx_claims_itemid ON Claims(itemID);

-- Index on ItemStatus.itemID for history queries
CREATE INDEX IF NOT EXISTS idx_status_itemid ON ItemStatus(itemID);

-- ========================================
-- SECTION 4: TRIGGERS (Automated Operations)
-- ========================================

-- Trigger: Auto-update dateUpdated on Item modification
CREATE TRIGGER IF NOT EXISTS trg_Item_BeforeUpdate
AFTER UPDATE ON Items
FOR EACH ROW
BEGIN
    UPDATE Items SET dateUpdated = datetime('now') WHERE id = NEW.id;
END;

-- Trigger: Increment employee itemsManaged when claim is approved
CREATE TRIGGER IF NOT EXISTS trg_Claims_AfterApprove
AFTER UPDATE OF verificationStatus ON Claims
FOR EACH ROW
WHEN NEW.verificationStatus = 'Approved' AND OLD.verificationStatus = 'Pending'
BEGIN
    UPDATE Employees 
    SET itemsManaged = itemsManaged + 1 
    WHERE id = NEW.handledBy AND NEW.handledBy IS NOT NULL;
END;

-- Trigger: Prevent deletion of claimed items
CREATE TRIGGER IF NOT EXISTS trg_Items_PreventDelete
BEFORE DELETE ON Items
FOR EACH ROW
WHEN OLD.isClaimed = 1
BEGIN
    SELECT RAISE(ABORT, 'Cannot delete claimed items');
END;

-- ========================================
-- SECTION 5: VIEWS FOR REPORTING
-- ========================================

-- View: Unclaimed Items with Days Waiting
CREATE VIEW IF NOT EXISTS vw_UnclaimedItems AS
SELECT 
    id,
    name,
    category,
    description,
    color,
    dateFound,
    foundAt,
    CAST(julianday('now') - julianday(dateFound) AS INTEGER) as daysUnclaimed
FROM Items
WHERE isClaimed = 0
ORDER BY dateFound DESC;

-- View: Pending Claims Summary
CREATE VIEW IF NOT EXISTS vw_PendingClaims AS
SELECT 
    c.id as claimID,
    c.claimDate,
    c.verificationCode,
    c.ownerFirstName || ' ' || c.ownerLastName as ownerName,
    i.name as itemName,
    i.category as itemCategory,
    i.foundAt as location,
    COALESCE(e.firstName || ' ' || e.lastName, 'Unassigned') as handler
FROM Claims c
JOIN Items i ON c.itemID = i.id
LEFT JOIN Employees e ON c.handledBy = e.id
WHERE c.verificationStatus = 'Pending';

-- View: Employee Performance Dashboard
CREATE VIEW IF NOT EXISTS vw_EmployeePerformance AS
SELECT 
    e.id,
    e.firstName || ' ' || e.lastName as employeeName,
    e.position,
    e.itemsManaged,
    COUNT(c.id) as totalClaimsHandled,
    SUM(CASE WHEN c.verificationStatus = 'Approved' THEN 1 ELSE 0 END) as approvedClaims,
    SUM(CASE WHEN c.verificationStatus = 'Pending' THEN 1 ELSE 0 END) as pendingClaims
FROM Employees e
LEFT JOIN Claims c ON e.id = c.handledBy
GROUP BY e.id, employeeName, e.position, e.itemsManaged;

-- View: Items by Category Statistics
CREATE VIEW IF NOT EXISTS vw_CategoryStats AS
SELECT 
    category,
    COUNT(*) as totalItems,
    SUM(CASE WHEN isClaimed = 0 THEN 1 ELSE 0 END) as unclaimed,
    SUM(CASE WHEN isClaimed = 1 THEN 1 ELSE 0 END) as claimed,
    ROUND(100.0 * SUM(CASE WHEN isClaimed = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) as claimRate
FROM Items
GROUP BY category
ORDER BY totalItems DESC;

-- ========================================
-- SECTION 6: SEED DATA
-- ========================================

-- Insert Employees
INSERT OR IGNORE INTO Employees (id, firstName, lastName, position, itemsManaged) VALUES
    (1, 'Arjun', 'Menon', 'Manager', 2),
    (2, 'Neha', 'Verma', 'Staff', 1),
    (4, 'Sneha', 'Reddy', 'Supervisor', 1),
    (7, 'Rahul', 'Nair', 'Manager', 3),
    (10, 'Anita', 'Kapoor', 'Assistant', 1);

-- Insert Sample Items
INSERT INTO Items (name, category, description, color, dateFound, foundAt, isClaimed) VALUES
    ('Laptop Dell XPS', 'Electronics', 'Silver laptop with stickers', 'Silver', '2025-01-02', 'City Library', 0),
    ('Maths Book', 'Books', 'R.D Sharma Class 12', 'Blue', '2025-01-05', 'Metro Station', 0),
    ('Blue Jacket', 'Clothing', 'Nike brand size M', 'Blue', '2025-01-07', 'Airport', 0),
    ('Water Bottle', 'Accessories', 'Steel 1L bottle', 'Steel', '2025-01-08', 'Park', 0),
    ('Physics Notes', 'Books', 'Handwritten notes', 'White', '2025-01-09', 'Railway Station', 0),
    ('Smartwatch', 'Electronics', 'Apple Watch Series 6', 'Black', '2025-01-12', 'University', 0),
    ('Umbrella', 'Accessories', 'Black foldable umbrella', 'Black', '2025-01-13', 'Theatre', 0);

-- Insert Sample Claims
INSERT INTO Claims (claimDate, verificationCode, ownerFirstName, ownerLastName, itemID, verificationStatus, handledBy) VALUES
    ('2025-01-05', 'VC101', 'Ramesh', 'Patil', 1, 'Pending', 1),
    ('2025-01-08', 'VC104', 'Preeti', 'Shah', 3, 'Pending', 4),
    ('2025-01-10', 'VC106', 'Isha', 'Menon', 4, 'Pending', NULL),
    ('2025-01-13', 'VC109', 'Sanjay', 'Shetty', 6, 'Pending', NULL);

-- ========================================
-- SECTION 7: COMMON QUERIES (Examples)
-- ========================================

-- Query: Get all unclaimed items
-- SELECT * FROM vw_UnclaimedItems;

-- Query: Get pending claims with JOINs
-- SELECT * FROM vw_PendingClaims;

-- Query: Employee performance
-- SELECT * FROM vw_EmployeePerformance ORDER BY approvedClaims DESC;

-- Query: Category statistics
-- SELECT * FROM vw_CategoryStats;

-- Query: Items unclaimed for over 7 days
-- SELECT * FROM vw_UnclaimedItems WHERE daysUnclaimed > 7;

-- ========================================
-- SECTION 8: STORED PROCEDURES (Conceptual)
-- ========================================
-- Note: SQLite does not support stored procedures
-- See stored_procedures_functions.sql for implementations
-- Actual logic implemented in Python (server.py)

-- ========================================
-- SECTION 9: SAMPLE TRANSACTIONS
-- ========================================

-- Transaction: Approve a claim
-- BEGIN TRANSACTION;
--     UPDATE Claims SET verificationStatus = 'Approved' WHERE id = 1;
--     UPDATE Items SET isClaimed = 1 WHERE id = (SELECT itemID FROM Claims WHERE id = 1);
--     INSERT INTO ItemStatus (itemID, status) VALUES ((SELECT itemID FROM Claims WHERE id = 1), 'Claimed');
-- COMMIT;

-- ========================================
-- SECTION 10: DATABASE MAINTENANCE
-- ========================================

-- Optimize database
-- VACUUM;
-- ANALYZE;
-- REINDEX;

-- Check integrity
-- PRAGMA integrity_check;

-- ========================================
-- END OF SQL IMPLEMENTATION
-- ========================================
