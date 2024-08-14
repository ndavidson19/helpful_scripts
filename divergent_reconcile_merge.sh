#!/bin/bash

# Function to prompt for user input
prompt_user() {
    read -p "$1: " response
    echo $response
}

# Function to check if a command was successful
check_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Get repository URLs
repo1_url=$(prompt_user "Enter the URL for the first repository")
repo2_url=$(prompt_user "Enter the URL for the second repository")

# Clone repositories
git clone $repo1_url repo1
check_success "Failed to clone first repository"
git clone $repo2_url repo2
check_success "Failed to clone second repository"

# Enter the first repo
cd repo1

# Create a new branch for merging
merge_branch="merge_$(date +%Y%m%d_%H%M%S)"
git checkout -b $merge_branch
check_success "Failed to create merge branch"

# Add the second repo as a remote
git remote add repo2 ../repo2
git fetch repo2
check_success "Failed to fetch from second repository"

# Prompt for the common ancestor commit
common_ancestor=$(prompt_user "Enter the common ancestor commit hash")

# Reset the merge branch to the common ancestor
git reset --hard $common_ancestor
check_success "Failed to reset to common ancestor"

# Merge the second repository's main branch with --allow-unrelated-histories
echo "Merging changes from the second repository..."
git merge --allow-unrelated-histories --no-commit --no-ff repo2/main

# Check if there are conflicts
if git diff --name-only --diff-filter=U | grep -q .; then
    echo "Conflicts detected. The following files have conflicts:"
    git diff --name-only --diff-filter=U
    echo "These conflicts have been left unresolved in the working directory."
    echo "You can now manually review and resolve these conflicts."
else
    echo "No conflicts detected. All changes have been merged successfully."
fi

echo "Merge process completed. The changes from repo2 have been merged into the '$merge_branch' branch."
echo "To review the changes and resolve any conflicts, you can:"
echo "1. Use 'git status' to see the current state of the repository"
echo "2. Use 'git diff' to see the changes in detail"
echo "3. Edit the conflicting files manually to resolve conflicts"
echo "4. Use 'git add' to stage resolved files"
echo "5. Once all conflicts are resolved, use 'git commit' to finalize the merge"
echo ""
echo "After resolving all conflicts and committing, you can merge this branch into your main branch:"
echo "git checkout main"
echo "git merge $merge_branch"

cd ..