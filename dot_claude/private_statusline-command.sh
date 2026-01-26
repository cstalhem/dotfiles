#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract key information
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
output_style=$(echo "$input" | jq -r '.output_style.name // "default"')

# Get relative path or basename
if [[ "$current_dir" == "$project_dir" ]]; then
    dir_display=$(basename "$current_dir")
else
    # Show relative path from project root
    rel_path="${current_dir#$project_dir/}"
    if [[ "$rel_path" == "$current_dir" ]]; then
        # Not in project dir, show basename
        dir_display=$(basename "$current_dir")
    else
        dir_display="$(basename "$project_dir")/$rel_path"
    fi
fi

# Get detailed git status if in a git repo (skip optional locks for performance)
git_info=""
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    # Get branch name
    branch=$(git -C "$current_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || echo "detached")

    # Get git status information
    git_status=$(git -C "$current_dir" --no-optional-locks status --porcelain=v1 --branch 2>/dev/null)

    # Initialize status indicators
    status_indicators=""

    # Check for staged changes (index)
    if echo "$git_status" | grep -q "^[MADRC]"; then
        status_indicators="${status_indicators}\033[32m+\033[0m"  # Green plus for staged
    fi

    # Check for unstaged changes (working tree)
    if echo "$git_status" | grep -q "^.[MD]"; then
        status_indicators="${status_indicators}\033[33m!\033[0m"  # Yellow exclamation for modified
    fi

    # Check for untracked files
    if echo "$git_status" | grep -q "^??"; then
        status_indicators="${status_indicators}\033[31m?\033[0m"  # Red question mark for untracked
    fi

    # Check for deleted files
    if echo "$git_status" | grep -q "^.D"; then
        status_indicators="${status_indicators}\033[31m✘\033[0m"  # Red X for deleted
    fi

    # Check for renamed files
    if echo "$git_status" | grep -q "^R"; then
        status_indicators="${status_indicators}\033[35m»\033[0m"  # Magenta arrow for renamed
    fi

    # Check for ahead/behind remote
    ahead_behind=""
    branch_line=$(echo "$git_status" | head -n1)
    if echo "$branch_line" | grep -q "ahead"; then
        ahead=$(echo "$branch_line" | sed -n 's/.*ahead \([0-9]*\).*/\1/p')
        ahead_behind="${ahead_behind}\033[36m↑${ahead}\033[0m"  # Cyan up arrow with count
    fi
    if echo "$branch_line" | grep -q "behind"; then
        behind=$(echo "$branch_line" | sed -n 's/.*behind \([0-9]*\).*/\1/p')
        ahead_behind="${ahead_behind}\033[36m↓${behind}\033[0m"  # Cyan down arrow with count
    fi

    # Check for merge conflicts
    if echo "$git_status" | grep -q "^UU\|^AA\|^DD"; then
        status_indicators="${status_indicators}\033[31m✖\033[0m"  # Red conflict indicator
    fi

    # Check for stashes
    stash_count=$(git -C "$current_dir" --no-optional-locks stash list 2>/dev/null | wc -l | tr -d ' ')
    if [ "$stash_count" -gt 0 ]; then
        status_indicators="${status_indicators}\033[34m*${stash_count}\033[0m"  # Blue asterisk with count
    fi

    # Build git info string
    # Color the branch based on cleanliness
    if [ -z "$status_indicators" ] && [ -z "$ahead_behind" ]; then
        # Clean repo - green branch
        branch_color="\033[32m"
    else
        # Dirty repo - cyan branch
        branch_color="\033[36m"
    fi

    git_info=$(printf " \033[2m(\033[0m%b%s\033[0m" "$branch_color" "$branch")

    # Add ahead/behind indicators
    if [ -n "$ahead_behind" ]; then
        git_info=$(printf "%b %b" "$git_info" "$ahead_behind")
    fi

    # Add status indicators
    if [ -n "$status_indicators" ]; then
        git_info=$(printf "%b %b" "$git_info" "$status_indicators")
    fi

    git_info=$(printf "%b\033[2m)\033[0m" "$git_info")
fi

# Calculate context window percentage and show total size
context_info=""
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    pct=$((current * 100 / size))

    # Format size with thousands separator for readability
    size_formatted=$(printf "%'d" "$size")

    context_info=$(printf " \033[2m[\033[0m\033[33m%d%% of %s tokens\033[0m\033[2m]\033[0m" "$pct" "$size_formatted")
fi

# Check thinking status from settings file
thinking_status=""
if [ -f "/Users/cstalhem/.claude/settings.json" ]; then
    thinking_enabled=$(jq -r '.alwaysThinkingEnabled // false' "/Users/cstalhem/.claude/settings.json")
    if [ "$thinking_enabled" = "true" ]; then
        thinking_status=$(printf " \033[2m[\033[0m\033[35m󰟶\033[0m\033[2m]\033[0m")
    fi
fi

# Format output style (lowercase for cleaner display)
style_display=$(echo "$output_style" | tr '[:upper:]' '[:lower:]')
style_info=$(printf " \033[2m[\033[0m\033[32m%s\033[0m\033[2m]\033[0m" "$style_display")

# Build status line with dimmed colors
printf "\033[2m%s\033[0m \033[2min\033[0m \033[34m%s\033[0m%s%s%s%s" \
    "$model_name" \
    "$dir_display" \
    "$git_info" \
    "$context_info" \
    "$style_info" \
    "$thinking_status"
