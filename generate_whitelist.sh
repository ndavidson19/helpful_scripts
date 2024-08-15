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

# Parse command line arguments
threshold=50
output_file="whitelist.txt"

while getopts ":t:o:" opt; do
    case ${opt} in
        t )
            threshold=$OPTARG
            ;;
        o )
            output_file=$OPTARG
            ;;
        \? )
            echo "Usage: $0 [-t threshold] [-o output_file]" 1>&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Main script

# Get repository URLs and branch names
prompt_user "Enter the URL for your forked repository (repo1)" fork_url
prompt_user "Enter the URL for the original repository (repo2)" original_url
prompt_user "Enter the branch name in your forked repository" fork_branch "main"
prompt_user "Enter the branch name in the original repository" original_branch "main"
prompt_user "Enter the common ancestor commit hash" common_ancestor

# Validate repository URLs
if ! validate_git_url "$fork_url" || ! validate_git_url "$original_url"; then
    exit 1
fi

# Create a temporary directory
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

# Clone repositories
git clone "$fork_url" "$temp_dir/repo1"
git clone "$original_url" "$temp_dir/repo2"

# Change to the forked repository directory
cd "$temp_dir/repo1"

# Fetch the original repository
git remote add upstream "$original_url"
git fetch upstream

# Generate the list of changed files
changed_files=$(git diff --name-only "$common_ancestor" "$fork_branch")

# Initialize an empty array to store whitelisted files
whitelist=()

# Check each changed file
for file in $changed_files; do
    # Get the number of lines changed in repo1 compared to the common ancestor
    lines_changed_repo1=$(git diff "$common_ancestor" "$fork_branch" -- "$file" | grep -E '^[+-]' | wc -l)
    
    # Get the number of lines changed in repo2 compared to the common ancestor
    lines_changed_repo2=$(git diff "$common_ancestor" "upstream/$original_branch" -- "$file" | grep -E '^[+-]' | wc -l)
    
    # Calculate the percentage of changes in repo1
    total_changes=$((lines_changed_repo1 + lines_changed_repo2))
    if [ "$total_changes" -ne 0 ]; then
        percentage=$((lines_changed_repo1 * 100 / total_changes))
        
        # If the percentage of changes in repo1 is above the threshold, add to whitelist
        if [ "$percentage" -ge "$threshold" ]; then
            whitelist+=("$file")
        fi
    fi
done

# Write the whitelist to the output file
printf '%s\n' "${whitelist[@]}" > "$output_file"

echo "Whitelist generated and saved to $output_file"
echo "Total files in whitelist: ${#whitelist[@]}"
echo "You can use this whitelist with the merge script as follows:"
echo "./merge_script.sh -m theirs -w $(paste -sd, "$output_file")"