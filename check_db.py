
import sqlite3

db_path = "expense_tracker.db"

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

print("=== CAC BANG TRONG DATABASE ===")
cursor.execute("""
    SELECT name
    FROM sqlite_master
    WHERE type = 'table'
""")
print(cursor.fetchall())

print("\n=== CAU TRUC BANG expenses ===")
cursor.execute("PRAGMA table_info(expenses)")
for column in cursor.fetchall():
    print(column)

print("\n=== DU LIEU GIAO DICH ===")
cursor.execute("""
    SELECT id, title, category, amount, date
    FROM expenses
    ORDER BY id DESC
""")

rows = cursor.fetchall()

if rows:
    for row in rows:
        print(row)
else:
    print("Chua co giao dich nao.")

conn.close()
