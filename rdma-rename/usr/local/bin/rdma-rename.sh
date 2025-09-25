#!/bin/bash

# Function to run a command with retries
try_command() {
    local command="$1"
    local retries=5
    local interval=1

    for ((i=1; i<=retries; i++)); do
        eval "$command"
        if [ $? -eq 0 ]; then
            echo "Command succeeded: $command"
            return 0
        fi
        echo "Command failed: $command. Retrying in $interval seconds..."
        sleep $interval
    done

    echo "Failed to execute: $command after $retries attempts."
    return 1
}

# Define the commands as an array
commands=(
    "rdma dev set mlx5_1 name mezz_0"
    "rdma dev set mlx5_2 name mezz_1"
    "rdma dev set mlx5_3 name mezz_2"
    "rdma dev set mlx5_4 name mezz_3"
    "rdma dev set mlx5_5 name mlx5_1"
    "rdma dev set mlx5_6 name mlx5_2"
    "rdma dev set mlx5_7 name mlx5_3"
    "rdma dev set mlx5_8 name mlx5_4"
    "rdma dev set mlx5_9 name mlx5_5"
    "rdma dev set mlx5_10 name mlx5_6"
    "rdma dev set mlx5_11 name mlx5_7"
)

# Run each command
for cmd in "${commands[@]}"; do
    try_command "$cmd"
done