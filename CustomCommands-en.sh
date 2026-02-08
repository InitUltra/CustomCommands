#!/bin/bash
# CustomCommands
# Github: https://github.com/InitUltra/CustomCommands
# License under MIT
# Version: 0.1.0-alpha

set -eu

echo "====================================="
echo 
echo "Custom Commands - Bash Terminal"
echo 
echo "Author: InitUltra | Telegram: @InitSample | QQ: 3978688642"
echo
echo "====================================="

echo
echo -e "\033[1mCustom Commands is a script that packages local custom commands for bash-based Linux terminals.\033[0m"
echo
echo -e "\033[1mHow to use Custom Commands?\033[0m"
echo 
echo "1. Prepare a directory for your project and move the project scripts into it. Example: /sdcard/mycommand/mycommand.py"
echo "2. Write a command configuration file named mycommand.conf (must match the directory name). Format:

    Configuration uses 'key=value' format.
    
    name: Command name (required). Example: name=\"mycommand\"
    
    author: Project author. Example: author=\"John\"
    
    description: Project description. Example: description=\"shao yu nb\"
    
    depcmds: Commands to preload environment. Use brackets for multiple commands, executed before packaging.
    
    index: Main project file (required). Example: index=\"hello.sh\"
    
    run: Command to run the project (required), use \$@ for arguments. Example: run=\"python3 main.py \$@\"
"
echo 
echo -e "\033[1mHow does Custom Commands work?\033[0m"
echo 
echo "Custom Commands creates commands by writing a dedicated directory in the terminal's HOME path, giving execution permissions to each command file, and loading them into PATH."
echo

read -p "Enter target directory path: " cmddir
read -p "Enter target HOME path (leave blank for local HOME): " homedir

if [ -z "$homedir" ]; then
    homedir="$HOME"
fi

if [ -z "$cmddir" ]; then
    echo "Target directory cannot be empty!"
    exit 1
fi

project=$(basename "$cmddir")

# (Function) Parse configuration file
parse() {
    local config_file="$1"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" || "$line" == \#* ]] && continue
        
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            raw_value="${BASH_REMATCH[2]}"
            
            raw_value="${raw_value%,}"
            raw_value=$(echo "$raw_value" | xargs)
            
            # Check if value is an array
            if [[ "$raw_value" =~ ^\[(.*)\]$ ]]; then
                array_content="${BASH_REMATCH[1]}"
                
                IFS=',' read -ra temp_array <<< "$array_content"
                
                declare -ag "$key"
                
                local i=0
                for element in "${temp_array[@]}"; do
                    element=$(echo "$element" | sed "s/^[[:space:]]*['\"]//;s/['\"][[:space:]]*$//")
                    eval "$key[$i]=\"$element\""
                    ((i++))
                done
            else
                # Remove quotes from string value
                value="${raw_value%\"}"
                value="${value#\"}"
                value="${value%\'}"
                value="${value#\'}"
                
                declare -g "$key"="$value"
            fi
        fi
    done < "$config_file"
}

# Check if configuration file exists
if [ -f "$cmddir/$project.conf" ]; then
    parse "$cmddir/$project.conf"
else
    echo "Configuration file does not exist!"
    exit 1
fi

# Validate required fields
if [[ -z "${name+x}" ]] || [[ -z "${index+x}" ]] || [[ -z "${run+x}" ]]; then
    echo "Required fields are missing!"
    exit 1
fi

# Check for empty or whitespace-only values
if [[ -z "${name// }" ]] || [[ -z "${index// }" ]] || [[ -z "${run// }" ]]; then
    echo "Required fields have empty or whitespace-only values!"
    exit 1
fi

# Execute dependency commands if defined
if [[ -n "${depcmds+x}" ]] && [[ -n "$depcmds" ]]; then
    echo "Executing dependency command..."
    eval "$depcmds"
fi

# Set up custom commands directory
local_dir="$HOME/.local/cc/commands"
commands_dir="$local_dir/$name"

mkdir -p "$local_dir" "$commands_dir"

# Create command wrapper script
echo "Writing to loader file..."
cat > "$commands_dir/$name" << EOF
#!$(command -v bash)
# Project Name: $name
# Author: $author
# Description: $description

set -eu
cd "\$(dirname "\$0")"
$run
EOF

chmod +x "$commands_dir/$name"

echo "Copying project files..."
find "$cmddir" -type f ! -name "$project.conf" -exec cp {} "$commands_dir/" \;
touch "$commands_dir/with.dtft"

# Update PATH in bashrc
bashrc_file="$homedir/.bashrc"
if [ ! -f "$bashrc_file" ]; then
    touch "$bashrc_file"
fi

# Check if command already exists in PATH
if grep -q "export PATH=\"\$PATH:$commands_dir\"" "$bashrc_file" || \
   grep -q "export PATH=\"\$PATH:.*:$commands_dir\"" "$bashrc_file" || \
   grep -q "export PATH=\"\$PATH:$commands_dir:.*\"" "$bashrc_file"; then
    echo "The command already exists."
    exit 0
fi

# Add commands directory to PATH
echo "Loading command with environment..."
if grep -q "^export PATH=" "$bashrc_file"; then
    sed -i "/^export PATH=/ s|$|:$commands_dir|" "$bashrc_file"
else
    echo "export PATH=\"\$PATH:$commands_dir\"" >> "$bashrc_file"
fi

echo "Done. This file will be closed in 3 seconds."
sleep 3
exec bash