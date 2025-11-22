-- Lost & Found Management System - Complete SQL Database Schema
-- Database: SQLite
-- Includes: Core tables, RBAC implementation, triggers, functions, and seed data

-- ========================================
-- PART 1: CORE DATABASE TABLES
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

-- Users Table (Role-Based Access Control)
-- This table implements RBAC with granular privileges for each user
CREATE TABLE IF NOT EXISTS Users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,  -- In production, this would be hashed
    fullName TEXT NOT NULL,
    role TEXT NOT NULL,  -- Admin, Manager, Staff, Viewer
    email TEXT,
    canRead INTEGER DEFAULT 1,    -- Can view items, claims, employees
    canWrite INTEGER DEFAULT 0,   -- Can add new items, submit reports
    canApprove INTEGER DEFAULT 0, -- Can approve/reject claims
    canDelete INTEGER DEFAULT 0,  -- Can delete items and claims
    isActive INTEGER DEFAULT 1,   -- Account is active and can login
    createdDate TEXT DEFAULT (datetime('now')),
    lastLogin TEXT
);

-- UserAuditLog Table (Track User Actions)
CREATE TABLE IF NOT EXISTS UserAuditLog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    userID INTEGER NOT NULL,
    username TEXT NOT NULL,
    action TEXT NOT NULL,
    tableName TEXT,
    recordID INTEGER,
    actionDate TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (userID) REFERENCES Users(id)
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

-- Seed Users (Role-Based Access Control)
INSERT OR IGNORE INTO Users (id, username, password, fullName, role, email, canRead, canWrite, canApprove, canDelete, isActive) VALUES
    (1, 'admin', 'admin123', 'System Administrator', 'Admin', 'admin@lostandfound.edu', 1, 1, 1, 1, 1),
    (2, 'manager_arjun', 'manager123', 'Arjun Menon', 'Manager', 'arjun.menon@lostandfound.edu', 1, 1, 1, 0, 1),
    (3, 'staff_neha', 'staff123', 'Neha Verma', 'Staff', 'neha.verma@lostandfound.edu', 1, 1, 0, 0, 1),
    (4, 'viewer_public', 'viewer123', 'Public Viewer', 'Viewer', 'viewer@lostandfound.edu', 1, 0, 0, 0, 1);

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

-- ========================================
-- PART 2: ROLE-BASED ACCESS CONTROL (RBAC)
-- ========================================

-- PRIVILEGE DEFINITIONS:
-- canRead = 1: Can view items, claims, employees
-- canWrite = 1: Can add new items, submit reports
-- canApprove = 1: Can approve/reject claims
-- canDelete = 1: Can delete items and claims
-- isActive = 1: Account is active and can login

-- ROLE HIERARCHY:
-- +------------------+--------+---------+-----------+----------+
-- | Role             | Read   | Write   | Approve   | Delete   |
-- +------------------+--------+---------+-----------+----------+
-- | Admin            | ✓ Yes  | ✓ Yes   | ✓ Yes     | ✓ Yes    |
-- | Manager          | ✓ Yes  | ✓ Yes   | ✓ Yes     | ✗ No     |
-- | Staff            | ✓ Yes  | ✓ Yes   | ✗ No      | ✗ No     |
-- | Viewer (Public)  | ✓ Yes  | ✗ No    | ✗ No      | ✗ No     |
-- +------------------+--------+---------+-----------+----------+

-- ========================================
-- RBAC QUERIES FOR ACCESS CONTROL
-- ========================================

-- Login Authentication Query
-- SELECT id, username, fullName, role, canRead, canWrite, canApprove, canDelete
-- FROM Users WHERE username = ? AND password = ? AND isActive = 1;

-- Check Read Permission
-- SELECT canRead FROM Users WHERE username = ? AND isActive = 1;

-- Check Write Permission
-- SELECT canWrite FROM Users WHERE username = ? AND isActive = 1;

-- Check Approve Permission
-- SELECT canApprove FROM Users WHERE username = ? AND isActive = 1;

-- Check Delete Permission
-- SELECT canDelete FROM Users WHERE username = ? AND isActive = 1;

-- Update Last Login
-- UPDATE Users SET lastLogin = datetime('now') WHERE username = ?;

-- View All Users and Privileges
-- SELECT username, fullName, role,
--     CASE WHEN canRead = 1 THEN '✓ Yes' ELSE '✗ No' END as 'Read Access',
--     CASE WHEN canWrite = 1 THEN '✓ Yes' ELSE '✗ No' END as 'Write Access',
--     CASE WHEN canApprove = 1 THEN '✓ Yes' ELSE '✗ No' END as 'Approve Access',
--     CASE WHEN canDelete = 1 THEN '✓ Yes' ELSE '✗ No' END as 'Delete Access',
--     email, createdDate, lastLogin
-- FROM Users WHERE isActive = 1
-- ORDER BY CASE role WHEN 'Admin' THEN 1 WHEN 'Manager' THEN 2 WHEN 'Staff' THEN 3 WHEN 'Viewer' THEN 4 END;

-- ========================================
-- PRIVILEGE ENFORCEMENT EXAMPLES
-- ========================================

-- Example 1: Viewer tries to add item (DENIED)
-- Query: SELECT canWrite FROM Users WHERE username = 'viewer_public';
-- Result: 0 (Cannot write) → Server returns 403 Forbidden

-- Example 2: Staff tries to approve claim (DENIED)
-- Query: SELECT canApprove FROM Users WHERE username = 'staff_neha';
-- Result: 0 (Cannot approve) → Approve button hidden in UI

-- Example 3: Manager approves claim (ALLOWED)
-- Query: SELECT canApprove FROM Users WHERE username = 'manager_arjun';
-- Result: 1 (Can approve) → Transaction executes successfully

-- Example 4: Admin deletes old item (ALLOWED)
-- Query: SELECT canDelete FROM Users WHERE username = 'admin';
-- Result: 1 (Can delete) → DELETE query executes

-- ========================================
-- SECURITY: PRIVILEGE ESCALATION PREVENTION
-- ========================================

-- Trigger: Prevent users from modifying their own privileges
CREATE TRIGGER IF NOT EXISTS trg_PreventPrivilegeEscalation
BEFORE UPDATE ON Users
FOR EACH ROW
WHEN OLD.id = NEW.id AND OLD.role != 'Admin'
BEGIN
    SELECT RAISE(FAIL, 'Users cannot modify their own privileges');
END;

-- ========================================
-- END OF SCHEMA
-- ========================================
-- ORDER BY dateFound DESC;
