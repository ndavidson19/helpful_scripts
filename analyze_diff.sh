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

while IFS= read -r line; do
    if [[ $line == "diff --git"* ]]; then
        file_a=$(echo "$line" | cut -d' ' -f3)
        file_b=$(echo "$line" | cut -d' ' -f4)
        file=${file_b#*/}
        
        # Only process .jsx, .css, .js, and .scss files
        if [[ $file =~ \.(jsx|css|js|scss)$ ]]; then
            if grep -q "^new file mode" <<< "$(sed -n "/$line/,/^diff --git/p" "$PATCH_FILE")"; then
                echo "$file" >> "$ADDED_FILES"
            elif grep -q "^deleted file mode" <<< "$(sed -n "/$line/,/^diff --git/p" "$PATCH_FILE")"; then
                echo "$file" >> "$DELETED_FILES"
            else
                echo "$file" >> "$MODIFIED_FILES"
            fi

            if grep -q "^Binary files" <<< "$(sed -n "/$line/,/^diff --git/p" "$PATCH_FILE")"; then
                echo "$file" >> "$BINARY_FILES"
            fi
        fi
    fi
done < "$PATCH_FILE"

# Generate report
echo "=== Patch Analysis Report ==="
echo "Total lines in patch: $(count_lines "$PATCH_FILE")"
echo ""
echo "Added files: $(count_lines "$ADDED_FILES")"
echo "Modified files: $(count_lines "$MODIFIED_FILES")"
echo "Deleted files: $(count_lines "$DELETED_FILES")"
echo "Binary files changed: $(count_lines "$BINARY_FILES")"
echo ""

echo "Top 10 most changed files (.jsx, .css, .js, .scss):"
grep -E "^[+-]" "$PATCH_FILE" | grep -vE "^(---|\+\+\+)" | cut -c2- | grep -E "\.(jsx|css|js|scss)$" | sort | uniq -c | sort -rn | head -n 10

echo ""
echo "Files most likely to cause conflicts (.jsx, .css, .js, .scss):"
grep -E "^[+-]" "$PATCH_FILE" | grep -vE "^(---|\+\+\+)" | cut -c2- | grep -E "\.(jsx|css|js|scss)$" | sort | uniq -c | sort -rn | awk '$1 > 10 {print $0}' | head -n 10

echo ""
echo "Detailed file lists:"
echo "Added files (.jsx, .css, .js, .scss):"
cat "$ADDED_FILES"
echo ""
echo "Modified files (.jsx, .css, .js, .scss):"
cat "$MODIFIED_FILES"
echo ""
echo "Deleted files (.jsx, .css, .js, .scss):"
cat "$DELETED_FILES"
echo ""
echo "Binary files changed (.jsx, .css, .js, .scss):"
cat "$BINARY_FILES"

# Clean up temporary files
rm "$ADDED_FILES" "$MODIFIED_FILES" "$DELETED_FILES" "$BINARY_FILES"