#!/bin/bash

set -euo pipefail

# Function to prompt for user input
prompt_user() {
    local prompt="$1"
    local variable_name="$2"
    local default_value="${3:-}"
    
    if [[ -n "$default_value" ]]; then
        prompt+=" (default: $default_value)"
    fi
    
    read -p "$prompt: " response
    response="${response:-$default_value}"
    
    if [[ -z "$response" ]]; then
        echo "Error: Input cannot be empty" >&2
        exit 1
    fi
    
    eval "$variable_name=\"$response\""
}

# Function to validate Git repository URL
validate_git_url() {
    local url="$1"
    if ! git ls-remote "$url" &> /dev/null; then
        echo "Error: Invalid or inaccessible Git repository: $url" >&2
        return 1
    fi
}

# Function to safely clone a repository
safe_clone() {
    local url="$1"
    local dir="$2"
    if ! git clone "$url" "$dir"; then
        echo "Error: Failed to clone repository: $url" >&2
        exit 1
    fi
}

# Function to resolve conflicts automatically where possible
resolve_conflicts() {
    local conflicts
    local unmerged_files=()
    conflicts=$(git diff --name-only --diff-filter=U)
    for file in $conflicts; do
        if [[ $file == *.json ]]; then
            if command -v jq &> /dev/null; then
                if jq -s '.[0] * .[1]' "$file" > "${file}.merged"; then
                    mv "${file}.merged" "$file"
                    git add "$file"
                    echo "Automatically resolved conflict in $file"
                else
                    echo "Could not automatically resolve conflict in $file"
                    unmerged_files+=("$file")
                fi
            else
                echo "jq is not installed. Skipping automatic resolution for $file"
                unmerged_files+=("$file")
            fi
        elif [[ $file == *.css || $file == *.scss ]]; then
            sed -e '/^<<<<<<</d' -e '/^>>>>>>>/d' -e '/^=======/d' "$file" > "${file}.merged"
            mv "${file}.merged" "$file"
            git add "$file"
            echo "Kept both changes in $file (may need manual review)"
        else
            echo "Manual resolution needed for $file"
            unmerged_files+=("$file")
        fi
    done
    
    # Output unmerged files to a text file
    if [ ${#unmerged_files[@]} -ne 0 ]; then
        printf '%s\n' "${unmerged_files[@]}" > unmerged_files.txt
        echo "List of files that could not be automatically merged has been saved to unmerged_files.txt"
    fi
}

# Main script

# Get repository URLs
prompt_user "Enter the URL for the first repository" repo1_url
prompt_user "Enter the URL for the second repository" repo2_url

# Validate repository URLs
if ! validate_git_url "$repo1_url" || ! validate_git_url "$repo2_url"; then
    exit 1
fi

# Create a temporary directory for our work
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Clone repositories
safe_clone "$repo1_url" "$temp_dir/repo1"
safe_clone "$repo2_url" "$temp_dir/repo2"

# Enter the first repo
cd "$temp_dir/repo1" || exit 1

# Create a new branch for merging
merge_branch="merge_$(date +%Y%m%d_%H%M%S)"
git checkout -b "$merge_branch"

# Add the second repo as a remote
git remote add repo2 "../repo2"
git fetch repo2

# Merge changes from repo2
echo "Merging changes from the second repository..."
if ! git merge --no-commit --no-ff repo2/main; then
    echo "Merge resulted in conflicts. Attempting to resolve..."
    resolve_conflicts
fi

# Check remaining conflicts
remaining_conflicts=$(git diff --name-only --diff-filter=U)
if [ -n "$remaining_conflicts" ]; then
    echo "The following files still have conflicts that need manual resolution:"
    echo "$remaining_conflicts"
    echo "Please resolve these conflicts manually, then run 'git add' on the resolved files."
else
    echo "All conflicts have been resolved automatically."
    git commit -m "Merged changes from repo2"
fi

echo "Merge process completed. The changes from repo2 have been merged into the '$merge_branch' branch."
echo "To review the changes and resolve any remaining conflicts, you can:"
echo "1. Use 'git status' to see the current state of the repository"
echo "2. Use 'git diff' to see the changes in detail"
echo "3. Edit any conflicting files manually to resolve remaining conflicts"
echo "4. Use 'git add' to stage resolved files"
echo "5. Once all conflicts are resolved, use 'git commit' to finalize the merge"
echo ""
echo "After resolving all conflicts and committing, you can merge this branch into your main branch:"
echo "git checkout main"
echo "git merge $merge_branch"

echo "The merged repository is located at: $temp_dir/repo1"

if [ -f unmerged_files.txt ]; then
    echo "Files that could not be automatically merged:"
    cat unmerged_files.txt
else
    echo "All files were successfully merged automatically."
fi