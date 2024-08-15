# Repository Merge and Whitelist Generation Scripts

This project contains two Bash scripts designed to help you merge changes from an original repository into your forked repository, with fine-grained control over which changes to keep.

1. `generate_whitelist.sh`: Generates a list of files that have been significantly modified in your fork.
2. `merge_script.sh`: Merges changes from the original repository into your fork, with options for different merge strategies and whitelisting.

## Prerequisites

- Bash shell
- Git

## Generate Whitelist Script

This script identifies files that have been significantly modified in your fork compared to the original repository.

### Usage

```bash
./generate_whitelist.sh [-t threshold] [-o output_file]
```

### Options

- `-t threshold`: The percentage threshold for considering a file as significantly changed (default: 50)
- `-o output_file`: The name of the file to save the whitelist (default: whitelist.txt)

### Example

```bash
./generate_whitelist.sh -t 60 -o my_whitelist.txt
```

This will generate a whitelist of files that have 60% or more of their changes in your fork.

### Interactive Prompts

The script will ask for the following information:

1. URL of your forked repository
2. URL of the original repository
3. Branch name in your forked repository (default: main)
4. Branch name in the original repository (default: main)
5. Common ancestor commit hash

## Merge Script

This script merges changes from the original repository into your fork, with options for different merge strategies and whitelisting.

### Usage

```bash
./merge_script.sh [-c] [-m strategy] [-w whitelist]
```

### Options

- `-c`: Allow conflicts (creates a pull request with unresolved conflicts)
- `-m strategy`: Merge strategy (manual, ours, or theirs)
- `-w whitelist`: Comma-separated list of files to whitelist (keep current changes)

### Examples

1. Use generated whitelist and take incoming changes for non-whitelisted files:
   ```bash
   ./merge_script.sh -m theirs -w $(cat my_whitelist.txt | paste -sd,)
   ```

2. Always keep current changes:
   ```bash
   ./merge_script.sh -m ours
   ```

3. Always take incoming changes:
   ```bash
   ./merge_script.sh -m theirs
   ```

4. Allow conflicts and resolve them in GitHub:
   ```bash
   ./merge_script.sh -c
   ```

5. Default behavior (manual conflict resolution):
   ```bash
   ./merge_script.sh
   ```

### Interactive Prompts

The script will ask for the following information:

1. URL of your forked repository
2. URL of the original repository
3. Branch name in the original repository to merge from (default: main)
4. Your GitHub username

## Workflow Example

Here's a step-by-step example of how to use these scripts together:

1. Generate the whitelist:
   ```bash
   ./generate_whitelist.sh -t 60 -o my_whitelist.txt
   ```

2. Review the generated whitelist in `my_whitelist.txt` and make any necessary adjustments.

3. Run the merge script using the generated whitelist:
   ```bash
   ./merge_script.sh -m theirs -w $(cat my_whitelist.txt | paste -sd,)
   ```

4. The script will create a new branch in your fork with the merged changes and provide a URL to create a pull request.

5. Review the changes in the pull request and make any necessary adjustments.

6. Merge the pull request to complete the process.

## Notes

- Always backup your repositories before running these scripts.
- The whitelist generation script uses a simple line-based diff to determine changes. This may not always accurately reflect semantic changes in code.
- Review the generated whitelist and merge results carefully to ensure they meet your needs.
- These scripts are provided as-is and may need adjustments based on your specific use case.

## Troubleshooting

If you encounter any issues:

1. Ensure both scripts have execute permissions: `chmod +x generate_whitelist.sh merge_script.sh`
2. Check that you have the necessary permissions for both repositories.
3. Verify that the common ancestor commit exists in both repositories.
4. If a script fails, read the error message carefully for hints on what went wrong.

For any persistent issues, please check the script contents and adjust as needed for your environment.