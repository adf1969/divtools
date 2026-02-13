import re
import sys
import os

def parse_qbo(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Extract transactions (<STMTTRN> ... </STMTTRN>)
    transactions = re.findall(r'<STMTTRN>(.*?)</STMTTRN>', content, re.DOTALL)

    parsed = []
    for txn in transactions:
        ttype = re.search(r'<TRNTYPE>([A-Z]+)', txn)
        date = re.search(r'<DTPOSTED>(\d+)', txn)
        amount = re.search(r'<TRNAMT>([-+]?\d+\.\d+)', txn)
        name = re.search(r'<NAME>(.*?)\s*(?:<|$)', txn)
        memo = re.search(r'<MEMO>(.*?)\s*(?:<|$)', txn)
        checknum = re.search(r'<CHECKNUM>(.*?)\s*(?:<|$)', txn)

        parsed.append({
            'type': ttype.group(1) if ttype else 'CHECK',
            'date': format_date(date.group(1)) if date else '',
            'amount': amount.group(1) if amount else '0.00',
            'name': name.group(1) if name else '',
            'memo': memo.group(1) if memo else '',
            'checknum': checknum.group(1) if checknum else ''
        })
    return parsed

def format_date(qbo_date):
    # QBO date format: YYYYMMDD
    return f"{qbo_date[4:6]}/{qbo_date[6:8]}/{qbo_date[0:4]}"

def write_iif(transactions, output_file, account_name="Bank"):
    with open(output_file, 'w', encoding='utf-8') as f:
        # IIF Header
        f.write("!TRNS\tTRNSTYPE\tDATE\tACCNT\tAMOUNT\tNAME\tMEMO\tNUM\n")
        f.write("!SPL\tTRNSTYPE\tDATE\tACCNT\tAMOUNT\tNAME\tMEMO\n")
        f.write("!ENDTRNS\n")

        for txn in transactions:
            ttype = "CHECK" if txn['amount'].startswith('-') else "DEP"
            amt = txn['amount']
            name = txn['name']
            memo = txn['memo']
            num = txn['checknum']
            date = txn['date']

            # TRNS line (main transaction)
            f.write(f"TRNS\t{ttype}\t{date}\t{account_name}\t{amt}\t{name}\t{memo}\t{num}\n")
            # SPL line (offset to Uncategorized Income/Expense)
            f.write(f"SPL\t{ttype}\t{date}\tUncategorized Income\t{-float(amt)}\t{name}\t{memo}\n")
            f.write("ENDTRNS\n")

def main():
    if len(sys.argv) < 2:
        print("Usage: python qbo_to_iif.py input.qbo [output.iif] [account_name]")
        sys.exit(1)

    qbo_file = sys.argv[1]
    iif_file = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(qbo_file)[0] + ".iif"
    account_name = sys.argv[3] if len(sys.argv) > 3 else "Bank"

    transactions = parse_qbo(qbo_file)
    if not transactions:
        print("No transactions found in QBO file.")
        sys.exit(1)

    write_iif(transactions, iif_file, account_name)
    print(f"Converted {len(transactions)} transactions to {iif_file}")

if __name__ == "__main__":
    main()
