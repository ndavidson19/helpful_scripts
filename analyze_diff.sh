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

# Analyze the patch file
echo "Analyzing patch file..."

# Extract file names and changes
grep -E "^diff --git|^new file mode|^deleted file mode|^Binary files" "$PATCH_FILE" | 
while read -r line; do
    if [[ $line == diff* ]]; then
        file=$(echo "$line" | cut -d' ' -f4 | sed 's|^b/||')
        if [[ $file =~ \.(jsx|css|js|scss)$ ]]; then
            echo "$file"
        fi
    elif [[ $line == "new file"* ]]; then
        echo "A $file"
    elif [[ $line == "deleted file"* ]]; then
        echo "D $file"
    elif [[ $line == "Binary"* ]]; then
        echo "B $file"
    fi
done | sort | uniq > file_changes.tmp

# Generate report
echo "=== Patch Analysis Report ==="
echo "Total lines in patch: $(count_lines "$PATCH_FILE")"
echo ""
echo "Changed files (.jsx, .css, .js, .scss):"
cat file_changes.tmp | wc -l
echo ""

echo "Top 10 most changed files (.jsx, .css, .js, .scss):"
grep -E "^[+-]" "$PATCH_FILE" | grep -vE "^(---|\+\+\+)" | cut -c2- | grep -E "\.(jsx|css|js|scss)$" | sort | uniq -c | sort -rn | head -n 10

echo ""
echo "Files most likely to cause conflicts (.jsx, .css, .js, .scss):"
grep -E "^[+-]" "$PATCH_FILE" | grep -vE "^(---|\+\+\+)" | cut -c2- | grep -E "\.(jsx|css|js|scss)$" | sort | uniq -c | sort -rn | awk '$1 > 10 {print $0}' | head -n 10

echo ""
echo "Detailed file changes:"
cat file_changes.tmp

# Clean up temporary files
rm file_changes.tmp