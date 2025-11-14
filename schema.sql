-- Lost & Found Management System - SQL Database Schema
-- Database: SQLite

-- ========================================
-- 1. CREATE TABLES
-- ========================================

-- Items Table
CREATE TABLE IF NOT EXISTS Items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    color TEXT,
    dateFound TEXT NOT NULL,
    foundAt TEXT NOT NULL,
    isClaimed INTEGER DEFAULT 0,
    dateUpdated TEXT DEFAULT (datetime('now'))
);

-- Claims Table
CREATE TABLE IF NOT EXISTS Claims (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    claimDate TEXT NOT NULL,
    verificationCode TEXT,
    ownerFirstName TEXT NOT NULL,
    ownerLastName TEXT NOT NULL,
    itemID INTEGER NOT NULL,
    verificationStatus TEXT DEFAULT 'Pending',
    handledBy INTEGER,
    FOREIGN KEY (itemID) REFERENCES Items(id)
);

-- Employees Table
CREATE TABLE IF NOT EXISTS Employees (
    id INTEGER PRIMARY KEY,
    firstName TEXT NOT NULL,
    lastName TEXT NOT NULL,
    position TEXT,
    itemsManaged INTEGER DEFAULT 0
);

-- ItemStatus History Table
CREATE TABLE IF NOT EXISTS ItemStatus (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    itemID INTEGER NOT NULL,
    status TEXT NOT NULL,
    statusDate TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (itemID) REFERENCES Items(id)
);

-- ========================================
-- 2. CREATE TRIGGERS (trg_Item_BeforeUpdate)
-- ========================================

-- Trigger: Automatically update dateUpdated when an Item is modified
CREATE TRIGGER IF NOT EXISTS trg_Item_BeforeUpdate
AFTER UPDATE ON Items
FOR EACH ROW
BEGIN
    UPDATE Items SET dateUpdated = datetime('now') WHERE id = NEW.id;
END;

-- ========================================
-- 3. SEED DATA
-- ========================================

-- Seed Employees
INSERT OR IGNORE INTO Employees (id, firstName, lastName, position, itemsManaged) VALUES
    (1, 'Arjun', 'Menon', 'Manager', 2),
    (2, 'Neha', 'Verma', 'Staff', 1),
    (4, 'Sneha', 'Reddy', 'Supervisor', 1),
    (7, 'Rahul', 'Nair', 'Manager', 3),
    (10, 'Anita', 'Kapoor', 'Assistant', 1);

-- Seed Items (Unclaimed found items)
INSERT INTO Items (name, category, description, color, dateFound, foundAt, isClaimed, dateUpdated) VALUES
    ('Laptop Dell XPS', 'Electronics', 'Silver with stickers', 'Silver', '2025-01-02', 'City Library', 0, datetime('now')),
    ('Maths Book', 'Books', 'R.D Sharma Class 12', 'Blue', '2025-01-05', 'Metro Station', 0, datetime('now')),
    ('Blue Jacket', 'Clothing', 'Nike size M', 'Blue', '2025-01-07', 'Airport', 0, datetime('now')),
    ('Water Bottle', 'Accessories', 'Steel 1L', 'Steel', '2025-01-08', 'Park', 0, datetime('now')),
    ('Physics Notes', 'Books', 'Handwritten', 'White', '2025-01-09', 'Railway Station', 0, datetime('now')),
    ('Smartwatch', 'Electronics', 'Apple Watch 6', 'Black', '2025-01-12', 'University', 0, datetime('now')),
    ('Umbrella', 'Accessories', 'Black foldable', 'Black', '2025-01-13', 'Theatre', 0, datetime('now'));

-- Seed Claims (Pending claims for review)
INSERT INTO Claims (claimDate, verificationCode, ownerFirstName, ownerLastName, itemID, verificationStatus, handledBy) VALUES
    ('2025-01-05', 'VC101', 'Ramesh', 'Patil', 1, 'Pending', 1),
    ('2025-01-08', 'VC104', 'Preeti', 'Shah', 3, 'Pending', 4),
    ('2025-01-10', 'VC106', 'Isha', 'Menon', 4, 'Pending', NULL),
    ('2025-01-13', 'VC109', 'Sanjay', 'Shetty', 6, 'Pending', NULL);

-- ========================================
-- 4. SAMPLE QUERIES (documented)
-- ========================================

-- Query 1: Dashboard Summary (Metrics)
-- SELECT 
--     CASE WHEN isClaimed = 0 THEN 'Unclaimed' ELSE 'Claimed' END as Status,
--     COUNT(*) as TotalItems,
--     AVG(julianday('now') - julianday(dateFound)) as AverageDaysUnclaimed
-- FROM Items
-- GROUP BY isClaimed;

-- Query 2: Employee Performance
-- SELECT 
--     id as employeeID,
--     firstName,
--     lastName,
--     position,
--     itemsManaged as ItemsManaged
-- FROM Employees
-- ORDER BY itemsManaged DESC;

-- Query 3: Pending Claims Report (Multi-table join)
-- SELECT 
--     c.id as claimID,
--     c.claimDate,
--     c.verificationCode,
--     c.ownerFirstName as OwnerFirstName,
--     c.ownerLastName as OwnerLastName,
--     i.name as itemName,
--     i.category as itemCategory,
--     i.foundAt as FoundAtLocation,
--     e.firstName || ' ' || e.lastName as ManagingStaff
-- FROM Claims c
-- JOIN Items i ON c.itemID = i.id
-- LEFT JOIN Employees e ON c.handledBy = e.id
-- WHERE c.verificationStatus = 'Pending';

-- Query 4: Unclaimed Items (Public Search)
-- SELECT 
--     id as itemID,
--     name as itemName,
--     description as itemDescription,
--     category as itemCategory,
--     color,
--     dateFound,
--     foundAt as FoundAt,
--     (julianday('now') - julianday(dateFound)) as DaysUnclaimed
-- FROM Items
-- WHERE isClaimed = 0
-- ORDER BY dateFound DESC;
