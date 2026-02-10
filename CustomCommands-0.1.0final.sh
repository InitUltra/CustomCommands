#!/bin/bash
# CustomCommands
# Github: https://github.com/InitUltra/CustomCommands
# License under MIT
# Version: 0.1.0

set -eu

echo "====================================="
echo 
echo "Custom Commands - Bash Terminal"
echo 
echo "作者: InitUltra | Telegram: @InitSample | QQ: 3978688642"
echo
echo "====================================="

echo
echo -e "\033[1mCustom Commands是一个用于在以bash为主shell的Linux终端下包装本地自定义命令的脚本。\033[0m"
echo
echo -e "\033[1m如何使用Custom Commands?\033[0m"
echo 
echo "1.准备一个存放项目的目录，并将项目脚本移动到此目录下。如:/sdcard/mycommand/mycommand.py"
echo "2.编写命令配置文件mycommand.conf，须与目录同名。具体格式:

    配置文件使用 项+等于号+值 作为基本格式。
    
    name: 代表此命令的名称，必填。如 name=\"mycommand\"
    
    author: 代表此命令项目的作者。如 author=\"John\"
    
    description: 项目介绍。如 description=\"shao yu nb\"
    
    depcmds: 代表预装载环境的命令。可以使用方括号来承接多个命令，这些命令将在打包前完成执行。
    
    index: 代表项目的主文件，必填。如 index=\"hello.sh\"
    
    run: 代表运行项目的命令，必填，参数使用\$@表示。如 run=\"python3 main.py \$@\"
"
echo 
echo -e "\033[1mCustom Commands的原理?\033[0m"
echo 
echo "Custom Commands通过在终端的HOME路径下写入一个专有目录，并将目录中的每一个命令文件赋予执行权限并装载到PATH中来实现创建命令。"
echo

read -p "输入目标目录路径: " cmddir
read -p "输入目标HOME路径(不填则为本地HOME路径): " homedir

if [ -z "$homedir" ]; then
    homedir="$HOME"
fi

if [ -z "$cmddir" ]; then
    echo "目标目录不能为空!"
    exit 1
fi

project=$(basename "$cmddir")

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
                value="${raw_value%\"}"
                value="${value#\"}"
                value="${value%\'}"
                value="${value#\'}"
                
                declare -g "$key"="$value"
            fi
        fi
    done < "$config_file"
}

if [ -f "$cmddir/$project.conf" ]; then
    parse "$cmddir/$project.conf"
else
    echo "配置文件不存在!"
    exit 1
fi

if [[ -z "${name+x}" ]] || [[ -z "${index+x}" ]] || [[ -z "${run+x}" ]]; then
    echo "必填项缺失!"
    exit 1
fi

if [[ -z "${name// }" ]] || [[ -z "${index// }" ]] || [[ -z "${run// }" ]]; then
    echo "必填项的值为空或只包含空格!"
    exit 1
fi

if [[ -n "${depcmds+x}" ]] && [[ -n "$depcmds" ]]; then
    echo "Executing dependency command..."
    eval "$depcmds"
fi

local_dir="$HOME/.local/cc/commands"
commands_dir="$local_dir/$name"

mkdir -p "$local_dir" "$commands_dir"

echo "Write to the loader file..."
cat > "$commands_dir/$name" << EOF
#!$(command -v bash)
# Project Name: $name
${author:+# Author: $author}
${description:+# Description: $description}

set -eu
cd "\$(dirname "\$0")"
$run
EOF

chmod +x "$commands_dir/$name"

echo "Copy the project files...."
find "$cmddir" -type f ! -name "$project.conf" -exec cp {} "$commands_dir/" \;
touch "$commands_dir/with.dtft"

bashrc_file="$homedir/.bashrc"
if [ ! -f "$bashrc_file" ]; then
    touch "$bashrc_file"
fi

if grep -q "export PATH=\"\$PATH:$commands_dir\"" "$bashrc_file" || \
   grep -q "export PATH=\"\$PATH:.*:$commands_dir\"" "$bashrc_file" || \
   grep -q "export PATH=\"\$PATH:$commands_dir:.*\"" "$bashrc_file"; then
    echo "The command already exists."
    exit 0
fi

echo "Loading command with environment..."
if grep -q "^export PATH=" "$bashrc_file"; then
    sed -i "/^export PATH=/ s|$|:$commands_dir|" "$bashrc_file"
else
    echo "export PATH=\"\$PATH:$commands_dir\"" >> "$bashrc_file"
fi

echo "Done.This file will be closed in 3 seconds."
sleep 3
exec bash