#!/bin/bash

set -eo pipefail

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

# Function to resolve conflicts based on merge strategy
resolve_conflicts() {
    local conflicts
    local unmerged_files=()
    conflicts=$(git diff --name-only --diff-filter=U)
    for file in $conflicts; do
        if [[ " ${whitelist[@]} " =~ " ${file} " ]]; then
            git checkout --ours -- "$file"
            git add "$file"
            echo "Kept current changes for whitelisted file: $file"
        elif [ "$merge_strategy" = "ours" ]; then
            git checkout --ours -- "$file"
            git add "$file"
            echo "Kept current changes for: $file"
        elif [ "$merge_strategy" = "theirs" ]; then
            git checkout --theirs -- "$file"
            git add "$file"
            echo "Kept incoming changes for: $file"
        else
            echo "Manual resolution needed for: $file"
            unmerged_files+=("$file")
        fi
    done
    
    # Output unmerged files to a text file
    if [ ${#unmerged_files[@]} -ne 0 ]; then
        printf '%s\n' "${unmerged_files[@]}" > unmerged_files.txt
        echo "List of files that could not be automatically merged has been saved to unmerged_files.txt"
    fi
}

# Parse command line arguments
allow_conflicts=false
merge_strategy="manual"
whitelist=()

while getopts ":cm:w:" opt; do
    case ${opt} in
        c )
            allow_conflicts=true
            ;;
        m )
            merge_strategy=$OPTARG
            if [[ ! "$merge_strategy" =~ ^(manual|ours|theirs)$ ]]; then
                echo "Invalid merge strategy: $OPTARG" >&2
                exit 1
            fi
            ;;
        w )
            IFS=',' read -ra whitelist <<< "$OPTARG"
            ;;
        \? )
            echo "Invalid Option: -$OPTARG" 1>&2
            exit 1
            ;;
        : )
            echo "Invalid Option: -$OPTARG requires an argument" 1>&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Main script

# Get repository URLs
prompt_user "Enter the URL for your forked repository" fork_url
prompt_user "Enter the URL for the original repository" original_url
prompt_user "Enter the branch name in the original repository to merge from" original_branch "main"
prompt_user "Enter your GitHub username" github_username

# Validate repository URLs
if ! validate_git_url "$fork_url" || ! validate_git_url "$original_url"; then
    exit 1
fi

# Clone the forked repository
if ! git clone "$fork_url" forked_repo; then
    echo "Error: Failed to clone forked repository: $fork_url" >&2
    exit 1
fi

# Enter the forked repo
cd forked_repo || exit 1

# Ensure we're on the main branch
git checkout main

# Add the original repo as a remote
git remote add upstream "$original_url"
git fetch upstream

# Create a new branch for merging
merge_branch="merge_$(date +%Y%m%d_%H%M%S)"
git checkout -b "$merge_branch"

# Merge changes from the original repo
echo "Merging changes from the original repository..."
if ! git merge --no-commit --no-ff "upstream/$original_branch"; then
    if [ "$allow_conflicts" = true ] || [ "$merge_strategy" != "manual" ]; then
        echo "Conflicts detected. Applying merge strategy: $merge_strategy"
        resolve_conflicts
    else
        echo "Merge resulted in conflicts. Use -m flag to specify a merge strategy or -c to allow conflicts."
        exit 1
    fi
fi

# Check remaining conflicts
remaining_conflicts=$(git diff --name-only --diff-filter=U)
if [ -n "$remaining_conflicts" ]; then
    if [ "$allow_conflicts" = true ]; then
        echo "Committing merge with unresolved conflicts."
        git add .
        git commit -m "Merged changes from upstream/$original_branch (with conflicts)" --allow-empty
    else
        echo "The following files still have conflicts that need manual resolution:"
        echo "$remaining_conflicts"
        echo "Please resolve these conflicts manually, then run 'git add' on the resolved files."
        echo "After resolving conflicts, commit the changes and push the branch to your fork."
        echo "Then, you can create a pull request from your fork to the original repository."
        exit 1
    fi
else
    echo "All conflicts have been resolved automatically."
    git add .
    git commit -m "Merged changes from upstream/$original_branch"
fi

# Push the branch to the fork
git push -u origin "$merge_branch"

# Construct the pull request URL
repo_name=$(basename -s .git "$(git remote get-url origin)")
pr_url="https://github.com/$github_username/$repo_name/compare/main...$merge_branch"

echo "Changes have been pushed to your fork."
echo "To create a pull request, visit this URL:"
echo "$pr_url"

echo "Merge process completed. The changes from the original repository have been merged into the '$merge_branch' branch."
echo "To review the changes and resolve any remaining conflicts, you can:"
echo "1. Use 'git status' to see the current state of the repository"
echo "2. Use 'git diff' to see the changes in detail"
echo "3. Edit any conflicting files manually to resolve remaining conflicts"
echo "4. Use 'git add' to stage resolved files"
echo "5. Once all conflicts are resolved, use 'git commit' to finalize the merge"
echo "6. Push your changes with 'git push origin $merge_branch'"
echo "7. Create a pull request from your fork to the original repository"

if [ -f unmerged_files.txt ]; then
    echo "Files that could not be automatically merged:"
    cat unmerged_files.txt
else
    echo "All files were successfully merged automatically."
fi

echo "The merged repository is located at: $(pwd)"