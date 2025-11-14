#!/usr/bin/env python3
"""
Lost & Found Management System - Simple Python Backend
Connects SQLite database to HTML UI via REST API
"""

import sqlite3
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import os

DB_PATH = 'lostandfound.db'

# Initialize database
def init_db():
    """Create database and tables if they don't exist"""
    if not os.path.exists(DB_PATH):
        print(f"Creating database: {DB_PATH}")
        conn = sqlite3.connect(DB_PATH)
        with open('schema.sql', 'r') as f:
            conn.executescript(f.read())
        conn.commit()
        conn.close()
        print("Database created and seeded successfully!")
    else:
        print(f"Database already exists: {DB_PATH}")

def get_db():
    """Get database connection"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

class APIHandler(BaseHTTPRequestHandler):
    
    def _send_cors_headers(self):
        """Send CORS headers"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    
    def _send_json(self, data, status=200):
        """Send JSON response"""
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def _send_file(self, filepath):
        """Send file response"""
        try:
            with open(filepath, 'rb') as f:
                content = f.read()
            self.send_response(200)
            if filepath.endswith('.html'):
                self.send_header('Content-Type', 'text/html')
            elif filepath.endswith('.css'):
                self.send_header('Content-Type', 'text/css')
            elif filepath.endswith('.js'):
                self.send_header('Content-Type', 'application/javascript')
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            self.send_error(404, 'File not found')
    
    def do_OPTIONS(self):
        """Handle preflight requests"""
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path = parsed.path
        
        # Serve static files
        if path == '/' or path == '/ui.html':
            self._send_file('ui.html')
            return
        
        # API endpoints
        if path == '/api/items':
            self.get_items()
        elif path == '/api/claims':
            self.get_claims()
        elif path == '/api/metrics':
            self.get_metrics()
        elif path == '/api/employees':
            self.get_employees()
        else:
            self.send_error(404, 'Endpoint not found')
    
    def do_POST(self):
        """Handle POST requests"""
        parsed = urlparse(self.path)
        path = parsed.path
        
        # Read body
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode() if content_length > 0 else '{}'
        
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            self._send_json({'error': 'Invalid JSON'}, 400)
            return
        
        if path == '/api/items':
            self.add_item(data)
        elif path.startswith('/api/claims/') and path.endswith('/approve'):
            claim_id = path.split('/')[3]
            self.approve_claim(claim_id)
        else:
            self.send_error(404, 'Endpoint not found')
    
    def get_items(self):
        """GET /api/items - Return all unclaimed items"""
        try:
            conn = get_db()
            cursor = conn.execute("""
                SELECT 
                    id as itemID,
                    name as itemName,
                    description as itemDescription,
                    category as itemCategory,
                    color,
                    dateFound,
                    foundAt as FoundAt,
                    isClaimed,
                    CAST((julianday('now') - julianday(dateFound)) as INTEGER) as DaysUnclaimed
                FROM Items
                WHERE isClaimed = 0
                ORDER BY dateFound DESC
            """)
            items = [dict(row) for row in cursor.fetchall()]
            conn.close()
            self._send_json(items)
        except Exception as e:
            self._send_json({'error': str(e)}, 500)
    
    def add_item(self, data):
        """POST /api/items - Add new found item"""
        try:
            required = ['itemName', 'itemCategory', 'color', 'itemDescription', 'dateFound', 'FoundAt']
            if not all(k in data for k in required):
                self._send_json({'error': 'Missing required fields'}, 400)
                return
            
            conn = get_db()
            cursor = conn.execute("""
                INSERT INTO Items (name, category, description, color, dateFound, foundAt, isClaimed, dateUpdated)
                VALUES (?, ?, ?, ?, ?, ?, 0, datetime('now'))
            """, (data['itemName'], data['itemCategory'], data['itemDescription'], 
                  data['color'], data['dateFound'], data['FoundAt']))
            
            item_id = cursor.lastrowid
            conn.commit()
            
            # Return created item
            cursor = conn.execute("""
                SELECT id as itemID, name as itemName, category as itemCategory, 
                       description as itemDescription, color, dateFound, foundAt as FoundAt
                FROM Items WHERE id = ?
            """, (item_id,))
            item = dict(cursor.fetchone())
            conn.close()
            
            self._send_json(item, 201)
        except Exception as e:
            self._send_json({'error': str(e)}, 500)
    
    def get_claims(self):
        """GET /api/claims - Return pending claims"""
        try:
            conn = get_db()
            cursor = conn.execute("""
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
                JOIN Items i ON c.itemID = i.id
                LEFT JOIN Employees e ON c.handledBy = e.id
                WHERE c.verificationStatus = 'Pending'
            """)
            claims = [dict(row) for row in cursor.fetchall()]
            conn.close()
            self._send_json(claims)
        except Exception as e:
            self._send_json({'error': str(e)}, 500)
    
    def approve_claim(self, claim_id):
        """POST /api/claims/:id/approve - Approve a claim (Transaction)"""
        try:
            conn = get_db()
            
            # Begin transaction
            conn.execute('BEGIN TRANSACTION')
            
            # Get claim and item ID
            cursor = conn.execute("""
                SELECT itemID FROM Claims 
                WHERE id = ? AND verificationStatus = 'Pending'
            """, (claim_id,))
            row = cursor.fetchone()
            
            if not row:
                conn.rollback()
                self._send_json({'error': 'Claim not found or already processed'}, 404)
                return
            
            item_id = row['itemID']
            
            # Update claim status
            conn.execute("""
                UPDATE Claims 
                SET verificationStatus = 'Approved' 
                WHERE id = ?
            """, (claim_id,))
            
            # Update item (triggers trg_Item_BeforeUpdate)
            conn.execute("""
                UPDATE Items 
                SET isClaimed = 1, dateUpdated = datetime('now')
                WHERE id = ?
            """, (item_id,))
            
            # Insert status history
            conn.execute("""
                INSERT INTO ItemStatus (itemID, status, statusDate)
                VALUES (?, 'Claimed', datetime('now'))
            """, (item_id,))
            
            # Commit transaction
            conn.commit()
            conn.close()
            
            self._send_json({'success': True, 'claimID': claim_id, 'itemID': item_id})
        except Exception as e:
            if conn:
                conn.rollback()
            self._send_json({'error': str(e)}, 500)
    
    def get_metrics(self):
        """GET /api/metrics - Return dashboard metrics"""
        try:
            conn = get_db()
            
            # Unclaimed stats
            cursor = conn.execute("""
                SELECT 
                    COUNT(*) as totalUnclaimed,
                    AVG(julianday('now') - julianday(dateFound)) as avgDays
                FROM Items WHERE isClaimed = 0
            """)
            unclaimed = cursor.fetchone()
            
            # Claimed stats
            cursor = conn.execute("""
                SELECT COUNT(*) as totalClaimed FROM Items WHERE isClaimed = 1
            """)
            claimed = cursor.fetchone()
            
            conn.close()
            
            metrics = [
                {
                    'Status': 'Unclaimed',
                    'TotalItems': unclaimed['totalUnclaimed'] or 0,
                    'AverageDaysUnclaimed': round(unclaimed['avgDays'] or 0, 2)
                },
                {
                    'Status': 'Claimed',
                    'TotalItems': claimed['totalClaimed'] or 0,
                    'AverageDaysUnclaimed': 0
                }
            ]
            
            self._send_json(metrics)
        except Exception as e:
            self._send_json({'error': str(e)}, 500)
    
    def get_employees(self):
        """GET /api/employees - Return employee performance"""
        try:
            conn = get_db()
            cursor = conn.execute("""
                SELECT 
                    id as employeeID,
                    firstName,
                    lastName,
                    position,
                    itemsManaged as ItemsManaged
                FROM Employees
                ORDER BY itemsManaged DESC
            """)
            employees = [dict(row) for row in cursor.fetchall()]
            conn.close()
            self._send_json(employees)
        except Exception as e:
            self._send_json({'error': str(e)}, 500)
    
    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[{self.log_date_time_string()}] {format % args}")

def main():
    # Initialize database
    init_db()
    
    # Start server
    PORT = 8000
    server = HTTPServer(('localhost', PORT), APIHandler)
    print(f"\n Server running at http://localhost:{PORT}")
    print(f" Open UI at: http://localhost:{PORT}/ui.html")
    print(f" Database: {DB_PATH}")
    print("\nPress Ctrl+C to stop\n")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\n Server stopped")
        server.shutdown()

if __name__ == '__main__':
    main()
