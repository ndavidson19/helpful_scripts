#!/bin/bash

# Check if a filename was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <patch_file>"
    exit 1
fi

PATCH_FILE=$1

# Check if the patch file exists
if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: Patch file '$PATCH_FILE' not found."
    exit 1
fi

# Function to count lines in a file
count_lines() {
    wc -l < "$1" | tr -d ' '
}

# Temporary files
ADDED_FILES=$(mktemp)
MODIFIED_FILES=$(mktemp)
DELETED_FILES=$(mktemp)
BINARY_FILES=$(mktemp)

# Analyze the patch file
echo "Analyzing patch file..."

grep "^diff --git" "$PATCH_FILE" | while read -r line; do
    file_a=$(echo "$line" | cut -d' ' -f3)
    file_b=$(echo "$line" | cut -d' ' -f4)
    
    if grep -q "^new file mode" <<< "$(sed -n "/$line/,/^diff --git/p" "$PATCH_FILE")"; then
        echo "${file_b#*/}" >> "$ADDED_FILES"
    elif grep -q "^deleted file mode" <<< "$(sed -n "/$line/,/^diff --git/p" "$PATCH_FILE")"; then
        echo "${file_a#*/}" >> "$DELETED_FILES"
    else
        echo "${file_b#*/}" >> "$MODIFIED_FILES"
    fi

    if grep -q "^Binary files" <<< "$(sed -n "/$line/,/^diff --git/p" "$PATCH_FILE")"; then
        echo "${file_b#*/}" >> "$BINARY_FILES"
    fi
done

# Generate report
echo "=== Patch Analysis Report ==="
echo "Total lines in patch: $(count_lines "$PATCH_FILE")"
echo ""
echo "Added files: $(count_lines "$ADDED_FILES")"
echo "Modified files: $(count_lines "$MODIFIED_FILES")"
echo "Deleted files: $(count_lines "$DELETED_FILES")"
echo "Binary files changed: $(count_lines "$BINARY_FILES")"
echo ""

echo "Top 10 most changed files:"
grep -E "^[+-]" "$PATCH_FILE" | grep -vE "^(---|\+\+\+)" | cut -c2- | sort | uniq -c | sort -rn | head -n 10

echo ""
echo "Files most likely to cause conflicts:"
grep -E "^[+-]" "$PATCH_FILE" | grep -vE "^(---|\+\+\+)" | cut -c2- | sort | uniq -c | sort -rn | head -n 10 | while read -r count file; do
    if [ "$count" -gt 10 ]; then
        echo "$count $file"
    fi
done

echo ""
echo "Detailed file lists:"
echo "Added files:"
cat "$ADDED_FILES"
echo ""
echo "Modified files:"
cat "$MODIFIED_FILES"
echo ""
echo "Deleted files:"
cat "$DELETED_FILES"
echo ""
echo "Binary files changed:"
cat "$BINARY_FILES"

# Clean up temporary files
rm "$ADDED_FILES" "$MODIFIED_FILES" "$DELETED_FILES" "$BINARY_FILES"