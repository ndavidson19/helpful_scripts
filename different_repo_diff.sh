#!/bin/bash

# Clone both repos
git clone <url-of-repo1> repo1
git clone <url-of-repo2> repo2

# Enter the first repo
cd repo1

# Create a new branch for comparison
git checkout -b comparison_branch

# Add the second repo as a remote
git remote add repo2 ../repo2

# Fetch the branches from repo2
git fetch repo2

# Perform the diff
git diff comparison_branch..repo2/main > ../diff_output.patch

# Go back to the parent directory
cd ..