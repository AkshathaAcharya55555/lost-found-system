# Lost and Found Management System

A web-based Lost and Found Management System built with Python, SQLite, and vanilla JavaScript. This system helps organizations manage found items and claims efficiently with a clean, modern interface.

## Features

- **Public Search Portal**: Users can search for lost items by category, color, and location
- **Admin Panel**: Staff can manage found items and approve claims
- **Real-time Dashboard**: View metrics and statistics about items and claims
- **Database Transactions**: ACID-compliant claim approval process
- **Automated Triggers**: Automatic timestamp updates on item modifications

## Technology Stack

- **Backend**: Python 3.10 with built-in HTTP server
- **Database**: SQLite3 with normalized schema
- **Frontend**: HTML5, CSS3 (Tailwind), Vanilla JavaScript
- **Architecture**: REST API with client-side rendering

## Database Schema

The system uses a normalized relational database with 4 main tables:

- **Items**: Stores found item information
- **Claims**: Tracks user claims for items
- **Employees**: Manages staff information
- **ItemStatus**: Audit trail for item state changes

### Key SQL Features Implemented:

1. **Multi-table JOINs**: 3-table join for claim processing
2. **Database Trigger**: Auto-updates timestamps on item modifications
3. **Transactions**: ACID-compliant claim approval with BEGIN/COMMIT/ROLLBACK
4. **Aggregate Functions**: COUNT, AVG with date calculations
5. **Foreign Keys**: Referential integrity enforcement
6. **Indexes**: Optimized query performance

## Installation

### Prerequisites
- Python 3.10 or higher
- Modern web browser (Chrome, Firefox, Edge)

### Setup Steps

1. Clone the repository:
```bash
git clone https://github.com/AkshathaAcharya55555/lost-found-system.git
cd lost-found-system
```

2. Run the server:
```bash
python server.py
```

3. Open your browser and navigate to:
```
http://localhost:8000/ui.html
```

## Usage

### For Public Users (Lost Item Search)
1. Navigate to "Public Search"
2. Use filters to search for your lost item
3. Submit a claim if you find your item

### For Admin/Staff
1. Navigate to "Admin Panel"
2. Add newly found items
3. Review and approve pending claims
4. Monitor dashboard metrics

## Project Structure

```
├── server.py                  # Python HTTP server with REST API
├── ui.html                    # Frontend interface
├── schema.sql                 # Database schema with trigger
├── lostandfound.db           # SQLite database file
├── server_queries.sql        # SQL queries documentation
└── README.md                 # Project documentation
```

## API Endpoints

- `GET /api/items` - Retrieve unclaimed items
- `POST /api/items` - Add new found item
- `GET /api/claims` - Get pending claims
- `POST /api/claims` - Submit new claim
- `POST /api/claims/:id/approve` - Approve claim (transaction)
- `GET /api/metrics` - Dashboard statistics

## Database Highlights

### Transaction Example (Claim Approval)
```sql
BEGIN TRANSACTION;
-- Update claim status
UPDATE Claims SET verificationStatus = 'Approved' WHERE claimID = ?;
-- Mark item as claimed
UPDATE Items SET isClaimed = 1 WHERE id = ?;
-- Log status change
INSERT INTO ItemStatus (itemID, status) VALUES (?, 'Claimed');
COMMIT;
```

### Trigger Implementation
```sql
CREATE TRIGGER trg_Item_BeforeUpdate
AFTER UPDATE ON Items
FOR EACH ROW
BEGIN
    UPDATE Items SET dateUpdated = datetime('now') 
    WHERE id = NEW.id;
END;
```

## Testing

The system includes test data with:
- 9 sample items across different categories
- 6 pending claims for testing approval workflow
- 5 employee records

## Development Notes

- Uses Python's built-in `http.server` and `sqlite3` modules (no external dependencies)
- Implements proper SQL parameterization to prevent injection attacks
- Frontend uses Tailwind CSS CDN for styling
- All dates stored in ISO 8601 format (YYYY-MM-DD)

## Contributors

- Akshatha Acharya

## License

This project is for educational purposes as part of a Database Management Systems course.

## Acknowledgments

Built as a mini project for DBMS course demonstrating:
- Database design and normalization
- SQL query optimization
- Transaction management
- Trigger implementation
- Full-stack web development
