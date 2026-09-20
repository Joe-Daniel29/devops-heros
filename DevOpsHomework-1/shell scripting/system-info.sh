#!/bin/bash

# System Information Script
# Uses variables, read -p, mkdir, touch, echo, df, ps, and > redirection

current_date=$(date)
host_name=$(hostname)
user_name=$(whoami)
disk_usage=$(df -h)
running_processes=$(ps)

echo "===== System Information ====="
echo "Date: $current_date"
echo "Hostname: $host_name"
echo "Username: $user_name"

echo
echo "===== Disk Usage ====="
echo "$disk_usage"

echo
echo "===== Running Processes ====="
echo "$running_processes"

echo
read -p "Enter your name: " name
read -p "Enter your roll number: " roll_no
read -p "Enter a directory name to create: " dir_name

mkdir -p "$dir_name"
touch "$dir_name/process.log"
ps > "$dir_name/process.log"

echo
echo "My name is $name"
echo "My roll number is $roll_no"
echo "Created directory: $dir_name"
echo "Created file: $dir_name/process.log"
echo "Running processes saved to $dir_name/process.log using > redirection"
