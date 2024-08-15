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
output_file="whitelist.txt"

while getopts ":o:" opt; do
    case ${opt} in
        o )
            output_file=$OPTARG
            ;;
        \? )
            echo "Usage: $0 [-o output_file]" 1>&2
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
prompt_user "Enter the common ancestor commit hash" common_ancestor

# Validate repository URLs
if ! validate_git_url "$fork_url" || ! validate_git_url "$original_url"; then
    exit 1
fi

# Create a temporary directory
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

echo "Cloning repository..."
# Clone only the forked repository (repo1)
git clone "$fork_url" "$temp_dir/repo1"

# Change to the forked repository directory
cd "$temp_dir/repo1"

echo "Generating list of changed files..."
# Generate the list of changed files in repo1 since the common ancestor
changed_files=$(git diff --name-only "$common_ancestor" "$fork_branch")

# Write the changed files to the output file
echo "$changed_files" > "$output_file"

echo "Whitelist generated and saved to $output_file"
echo "Total files in whitelist: $(wc -l < "$output_file")"
echo "You can use this whitelist with the merge script as follows:"
echo "./merge_script.sh -m theirs -w $(paste -sd, "$output_file")"

# Display the contents of the whitelist
echo "Contents of the whitelist:"
cat "$output_file"