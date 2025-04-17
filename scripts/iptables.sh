#!/bin/bash
set -e

BACKUP_FILE="/root/iptables-backup-$(date +%F-%H%M%S).rules"
echo "[*] Backing up current iptables rules to $BACKUP_FILE"
iptables-save > "$BACKUP_FILE"

TEMP_DIR=$(mktemp -d)
declare -A TABLE_RULES

echo "[*] Extracting rules by table..."

current_table=""
while IFS= read -r line; do
    if [[ "$line" =~ ^\* ]]; then
    current_table="${line:1}"
    TABLE_RULES["$current_table"]="$TEMP_DIR/$current_table.rules"
    > "${TABLE_RULES[$current_table]}"
    elif [[ "$line" =~ ^-A ]]; then
    echo "$line" >> "${TABLE_RULES[$current_table]}"
    fi
done < "$BACKUP_FILE"

for table in "${!TABLE_RULES[@]}"; do
    echo "[*] Processing table: $table"
    RULE_FILE="${TABLE_RULES[$table]}"
    DEDUPED=$(sort "$RULE_FILE" | uniq)
    DUPS=$(sort "$RULE_FILE" | uniq -d)

    if [[ -n "$DUPS" ]]; then
    echo "[!] Duplicate rules in $table:"
    echo "$DUPS"
    fi

    echo "[*] Flushing $table rules..."
    iptables -t "$table" -F
    iptables -t "$table" -X

    echo "[*] Rebuilding $table rules..."
    while IFS= read -r rule; do
    echo "    → $rule"
    if ! eval "iptables -t $table $rule"; then
        echo "[!] Failed to apply: $rule"
    fi
    done <<< "$DEDUPED"
done

rm -rf "$TEMP_DIR"
echo "[+] iptables cleanup complete. Backup saved at: $BACKUP_FILE"