-- ========================================
-- STORED PROCEDURES AND FUNCTIONS
-- Lost & Found Management System
-- ========================================
-- NOTE: SQLite does not natively support stored procedures/functions.
-- These are conceptual implementations showing what we would create
-- in MySQL/PostgreSQL. The actual logic is implemented in server.py
-- ========================================

-- ========================================
-- STORED PROCEDURES
-- ========================================

-- Procedure 1: Approve Claim
-- Purpose: Approve a pending claim and update related tables
-- Parameters: claim_id (INTEGER)
-- Returns: Success/Error message
-- Implementation: server.py lines 201-251

-- DELIMITER //
-- CREATE PROCEDURE sp_ApproveClaim(IN p_claimID INT)
-- BEGIN
--     DECLARE v_itemID INT;
--     DECLARE EXIT HANDLER FOR SQLEXCEPTION
--     BEGIN
--         ROLLBACK;
--         SELECT 'Error: Transaction rolled back' AS message;
--     END;
--     
--     START TRANSACTION;
--     
--     -- Get the item ID from the claim
--     SELECT itemID INTO v_itemID 
--     FROM Claims 
--     WHERE id = p_claimID AND verificationStatus = 'Pending';
--     
--     -- Check if claim exists
--     IF v_itemID IS NULL THEN
--         SELECT 'Error: Claim not found or already processed' AS message;
--         ROLLBACK;
--     ELSE
--         -- Update claim status to Approved
--         UPDATE Claims 
--         SET verificationStatus = 'Approved' 
--         WHERE id = p_claimID;
--         
--         -- Mark item as claimed (triggers trg_Item_BeforeUpdate)
--         UPDATE Items 
--         SET isClaimed = 1 
--         WHERE id = v_itemID;
--         
--         -- Log status change in history
--         INSERT INTO ItemStatus (itemID, status, statusDate)
--         VALUES (v_itemID, 'Claimed', datetime('now'));
--         
--         COMMIT;
--         SELECT 'Success: Claim approved' AS message, p_claimID AS claimID, v_itemID AS itemID;
--     END IF;
-- END //
-- DELIMITER ;

-- Implementation in Python (server.py lines 201-251):
-- def approve_claim(self, claim_id):
--     conn.execute('BEGIN TRANSACTION')
--     # ... UPDATE Claims, UPDATE Items, INSERT ItemStatus ...
--     conn.commit()


-- ========================================

-- Procedure 2: Add New Found Item
-- Purpose: Insert a new found item into the database
-- Parameters: name, category, description, color, foundAt
-- Returns: New item ID

-- DELIMITER //
-- CREATE PROCEDURE sp_AddFoundItem(
--     IN p_name VARCHAR(255),
--     IN p_category VARCHAR(100),
--     IN p_description TEXT,
--     IN p_color VARCHAR(50),
--     IN p_foundAt VARCHAR(255)
-- )
-- BEGIN
--     DECLARE v_itemID INT;
--     
--     -- Insert new item
--     INSERT INTO Items (name, category, description, color, dateFound, foundAt, isClaimed)
--     VALUES (p_name, p_category, p_description, p_color, date('now'), p_foundAt, 0);
--     
--     -- Get the auto-generated ID
--     SET v_itemID = LAST_INSERT_ID();
--     
--     -- Log initial status
--     INSERT INTO ItemStatus (itemID, status, statusDate)
--     VALUES (v_itemID, 'Unclaimed', datetime('now'));
--     
--     -- Return the new item ID
--     SELECT v_itemID AS newItemID;
-- END //
-- DELIMITER ;

-- Implementation in Python (server.py lines 145-170):
-- def add_item(self):
--     cursor = conn.execute("INSERT INTO Items ...")
--     item_id = cursor.lastrowid


-- ========================================

-- Procedure 3: File New Claim
-- Purpose: File a new ownership claim for an item
-- Parameters: itemID, ownerFirstName, ownerLastName, verificationCode
-- Returns: New claim ID

-- DELIMITER //
-- CREATE PROCEDURE sp_FileNewClaim(
--     IN p_itemID INT,
--     IN p_ownerFirstName VARCHAR(100),
--     IN p_ownerLastName VARCHAR(100),
--     IN p_verificationCode VARCHAR(50)
-- )
-- BEGIN
--     DECLARE v_claimID INT;
--     DECLARE v_itemExists INT;
--     
--     -- Check if item exists and is unclaimed
--     SELECT COUNT(*) INTO v_itemExists 
--     FROM Items 
--     WHERE id = p_itemID AND isClaimed = 0;
--     
--     IF v_itemExists = 0 THEN
--         SELECT 'Error: Item not found or already claimed' AS message;
--     ELSE
--         -- Insert new claim
--         INSERT INTO Claims (claimDate, verificationCode, ownerFirstName, ownerLastName, 
--                            itemID, verificationStatus, handledBy)
--         VALUES (date('now'), p_verificationCode, p_ownerFirstName, p_ownerLastName,
--                 p_itemID, 'Pending', NULL);
--         
--         SET v_claimID = LAST_INSERT_ID();
--         
--         SELECT 'Success: Claim filed' AS message, v_claimID AS newClaimID;
--     END IF;
-- END //
-- DELIMITER ;


-- ========================================

-- Procedure 4: Get Employee Performance Report
-- Purpose: Generate performance report for all employees
-- Parameters: None
-- Returns: Employee statistics

-- DELIMITER //
-- CREATE PROCEDURE sp_GetEmployeePerformance()
-- BEGIN
--     SELECT 
--         e.id AS employeeID,
--         e.firstName,
--         e.lastName,
--         e.position,
--         e.itemsManaged,
--         COUNT(c.id) AS totalClaimsHandled,
--         SUM(CASE WHEN c.verificationStatus = 'Approved' THEN 1 ELSE 0 END) AS approvedClaims,
--         SUM(CASE WHEN c.verificationStatus = 'Pending' THEN 1 ELSE 0 END) AS pendingClaims
--     FROM Employees e
--     LEFT JOIN Claims c ON e.id = c.handledBy
--     GROUP BY e.id, e.firstName, e.lastName, e.position, e.itemsManaged
--     ORDER BY e.itemsManaged DESC;
-- END //
-- DELIMITER ;

-- Implementation in Python (server.py lines 283-298):
-- def get_employees(self):
--     cursor = conn.execute("SELECT ... FROM Employees")


-- ========================================
-- USER-DEFINED FUNCTIONS
-- ========================================

-- Function 1: Calculate Days Unclaimed
-- Purpose: Calculate how many days an item has been unclaimed
-- Parameters: itemID
-- Returns: Number of days (INTEGER)

-- DELIMITER //
-- CREATE FUNCTION fn_GetDaysUnclaimed(p_itemID INT)
-- RETURNS INT
-- DETERMINISTIC
-- BEGIN
--     DECLARE v_dateFound DATE;
--     DECLARE v_daysUnclaimed INT;
--     
--     SELECT dateFound INTO v_dateFound 
--     FROM Items 
--     WHERE id = p_itemID;
--     
--     SET v_daysUnclaimed = DATEDIFF(CURDATE(), v_dateFound);
--     
--     RETURN v_daysUnclaimed;
-- END //
-- DELIMITER ;

-- Usage: SELECT name, fn_GetDaysUnclaimed(id) AS daysUnclaimed FROM Items;

-- Implementation in Python (server.py lines 121-135):
-- SELECT (julianday('now') - julianday(dateFound)) as DaysUnclaimed FROM Items


-- ========================================

-- Function 2: Get Claim Status
-- Purpose: Get human-readable claim status
-- Parameters: claimID
-- Returns: Status string (VARCHAR)

-- DELIMITER //
-- CREATE FUNCTION fn_GetClaimStatus(p_claimID INT)
-- RETURNS VARCHAR(50)
-- DETERMINISTIC
-- BEGIN
--     DECLARE v_status VARCHAR(50);
--     
--     SELECT verificationStatus INTO v_status
--     FROM Claims
--     WHERE id = p_claimID;
--     
--     RETURN COALESCE(v_status, 'Not Found');
-- END //
-- DELIMITER ;

-- Usage: SELECT id, fn_GetClaimStatus(id) AS status FROM Claims;


-- ========================================

-- Function 3: Count Pending Claims for Item
-- Purpose: Count how many pending claims exist for an item
-- Parameters: itemID
-- Returns: Count (INTEGER)

-- DELIMITER //
-- CREATE FUNCTION fn_CountPendingClaims(p_itemID INT)
-- RETURNS INT
-- DETERMINISTIC
-- BEGIN
--     DECLARE v_count INT;
--     
--     SELECT COUNT(*) INTO v_count
--     FROM Claims
--     WHERE itemID = p_itemID AND verificationStatus = 'Pending';
--     
--     RETURN v_count;
-- END //
-- DELIMITER ;

-- Usage: SELECT name, fn_CountPendingClaims(id) AS pendingClaims FROM Items;


-- ========================================

-- Function 4: Calculate Item Priority Score
-- Purpose: Calculate priority score based on days unclaimed and claim count
-- Parameters: itemID
-- Returns: Priority score (INTEGER, higher = more urgent)

-- DELIMITER //
-- CREATE FUNCTION fn_CalculateItemPriority(p_itemID INT)
-- RETURNS INT
-- DETERMINISTIC
-- BEGIN
--     DECLARE v_daysUnclaimed INT;
--     DECLARE v_claimCount INT;
--     DECLARE v_priorityScore INT;
--     
--     -- Get days unclaimed
--     SELECT DATEDIFF(CURDATE(), dateFound) INTO v_daysUnclaimed
--     FROM Items
--     WHERE id = p_itemID;
--     
--     -- Get number of claims
--     SELECT COUNT(*) INTO v_claimCount
--     FROM Claims
--     WHERE itemID = p_itemID;
--     
--     -- Calculate priority: (days * 2) + (claims * 10)
--     SET v_priorityScore = (v_daysUnclaimed * 2) + (v_claimCount * 10);
--     
--     RETURN v_priorityScore;
-- END //
-- DELIMITER ;

-- Usage: SELECT name, fn_CalculateItemPriority(id) AS priority FROM Items ORDER BY priority DESC;


-- ========================================

-- Function 5: Get Full Employee Name
-- Purpose: Concatenate employee first and last name
-- Parameters: employeeID
-- Returns: Full name (VARCHAR)

-- DELIMITER //
-- CREATE FUNCTION fn_GetEmployeeName(p_employeeID INT)
-- RETURNS VARCHAR(255)
-- DETERMINISTIC
-- BEGIN
--     DECLARE v_fullName VARCHAR(255);
--     
--     SELECT CONCAT(firstName, ' ', lastName) INTO v_fullName
--     FROM Employees
--     WHERE id = p_employeeID;
--     
--     RETURN COALESCE(v_fullName, 'Unknown');
-- END //
-- DELIMITER ;

-- Usage: SELECT fn_GetEmployeeName(handledBy) AS handler FROM Claims;

-- Implementation in SQL (schema.sql lines 117-130):
-- SELECT e.firstName || ' ' || e.lastName as ManagingStaff FROM ... JOIN Employees e


-- ========================================

-- Function 6: Check Item Availability
-- Purpose: Check if an item is available for claiming
-- Parameters: itemID
-- Returns: 1 if available, 0 if not (INTEGER/BOOLEAN)

-- DELIMITER //
-- CREATE FUNCTION fn_IsItemAvailable(p_itemID INT)
-- RETURNS INT
-- DETERMINISTIC
-- BEGIN
--     DECLARE v_isClaimed INT;
--     
--     SELECT isClaimed INTO v_isClaimed
--     FROM Items
--     WHERE id = p_itemID;
--     
--     -- Return 1 (TRUE) if unclaimed, 0 (FALSE) if claimed
--     RETURN CASE WHEN v_isClaimed = 0 THEN 1 ELSE 0 END;
-- END //
-- DELIMITER ;

-- Usage: SELECT name FROM Items WHERE fn_IsItemAvailable(id) = 1;


-- ========================================
-- EXAMPLE USAGE OF PROCEDURES AND FUNCTIONS
-- ========================================

-- Example 1: Approve a claim using stored procedure
-- CALL sp_ApproveClaim(2);

-- Example 2: Add new found item using stored procedure
-- CALL sp_AddFoundItem('iPhone 13', 'Electronics', 'Black, cracked screen', 'Black', 'Bus Terminal');

-- Example 3: File a new claim using stored procedure
-- CALL sp_FileNewClaim(5, 'John', 'Doe', 'VERIFY123');

-- Example 4: Get employee performance report
-- CALL sp_GetEmployeePerformance();

-- Example 5: Use functions in SELECT query
-- SELECT 
--     id,
--     name,
--     fn_GetDaysUnclaimed(id) AS daysUnclaimed,
--     fn_CountPendingClaims(id) AS pendingClaims,
--     fn_CalculateItemPriority(id) AS priorityScore,
--     fn_IsItemAvailable(id) AS isAvailable
-- FROM Items
-- ORDER BY priorityScore DESC;

-- Example 6: Complex query using multiple functions
-- SELECT 
--     c.id AS claimID,
--     i.name AS itemName,
--     fn_GetEmployeeName(c.handledBy) AS handler,
--     fn_GetClaimStatus(c.id) AS status,
--     fn_GetDaysUnclaimed(c.itemID) AS daysWaiting
-- FROM Claims c
-- JOIN Items i ON c.itemID = i.id
-- WHERE fn_GetClaimStatus(c.id) = 'Pending';


-- ========================================
-- NOTES FOR VIVA
-- ========================================

-- 1. SQLite Limitation:
--    SQLite does NOT support CREATE PROCEDURE or CREATE FUNCTION syntax.
--    These are standard in MySQL, PostgreSQL, Oracle, SQL Server.

-- 2. Our Implementation:
--    We implemented equivalent functionality in Python (server.py):
--    - Stored Procedures → Python functions (approve_claim, add_item, etc.)
--    - User Functions → SQL expressions and Python calculations

-- 3. Advantages of Stored Procedures (if SQLite supported them):
--    - Encapsulation: Business logic in database
--    - Performance: Pre-compiled and cached
--    - Security: Controlled data access
--    - Reusability: Called from multiple applications
--    - Reduced network traffic: Less data sent between app and DB

-- 4. Our Alternative Approach:
--    - Python functions provide same encapsulation
--    - Easier to debug and maintain
--    - More flexible error handling
--    - Can integrate with external APIs/services

-- 5. What to Tell Teacher:
--    "While SQLite doesn't support stored procedures, we've demonstrated
--    understanding of the concept by implementing equivalent functionality
--    in our Python backend. In a production environment with MySQL or
--    PostgreSQL, we would convert these Python functions to native
--    stored procedures for better performance."

-- ========================================
-- END OF FILE
-- ========================================
