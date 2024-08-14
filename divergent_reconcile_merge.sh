#!/bin/bash

set -e

# Function to prompt for user input
prompt_user() {
    read -p "$1: " response
    echo $response
}

# Get repository URLs
repo1_url=$(prompt_user "Enter the URL for the first repository")
repo2_url=$(prompt_user "Enter the URL for the second repository")

# Clone repositories
git clone $repo1_url repo1
git clone $repo2_url repo2

# Enter the first repo
cd repo1

# Create a new branch for merging
merge_branch="merge_$(date +%Y%m%d_%H%M%S)"
git checkout -b $merge_branch

# Add the second repo as a remote
git remote add repo2 ../repo2
git fetch repo2

# Merge changes from repo2
echo "Merging changes from the second repository..."
git merge --no-commit --no-ff repo2/main

# Function to resolve conflicts automatically where possible
resolve_conflicts() {
    conflicts=$(git diff --name-only --diff-filter=U)
    for file in $conflicts; do
        if [[ $file == *.json ]]; then
            # For JSON files, use 'jq' to merge if possible
            if jq -s '.[0] * .[1]' "$file" > "${file}.merged"; then
                mv "${file}.merged" "$file"
                git add "$file"
                echo "Automatically resolved conflict in $file"
            else
                echo "Could not automatically resolve conflict in $file"
            fi
        elif [[ $file == *.css || $file == *.scss ]]; then
            # For CSS/SCSS files, keep both changes
            sed -e '/^<<<<<<</d' -e '/^>>>>>>>/d' -e '/^=======/d' "$file" > "${file}.merged"
            mv "${file}.merged" "$file"
            git add "$file"
            echo "Kept both changes in $file (may need manual review)"
        else
            echo "Manual resolution needed for $file"
        fi
    done
}

# Attempt to resolve conflicts
resolve_conflicts

# Check remaining conflicts
remaining_conflicts=$(git diff --name-only --diff-filter=U)
if [ -n "$remaining_conflicts" ]; then
    echo "The following files still have conflicts that need manual resolution:"
    echo "$remaining_conflicts"
    echo "Please resolve these conflicts manually, then run 'git add' on the resolved files."
else
    echo "All conflicts have been resolved automatically."
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

cd ..