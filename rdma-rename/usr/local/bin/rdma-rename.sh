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

# Check if mezz_0 already exists in ibdev2netdev output
echo "=== Checking current RDMA device names ==="
if ibdev2netdev | grep -q "^mezz_0 "; then
    echo "mezz_0 device already exists. Skipping RDMA device renaming."
    echo "Current RDMA devices:"
    ibdev2netdev
    SKIP_RDMA_RENAME=true
else
    echo "mezz_0 device not found. Will proceed with RDMA device renaming."
    SKIP_RDMA_RENAME=false
fi

echo ""

# Define the RDMA device rename commands as an array
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

# Run each RDMA device rename command only if mezz_0 doesn't exist
if [ "$SKIP_RDMA_RENAME" = false ]; then
    echo "=== Renaming RDMA devices ==="
    for cmd in "${commands[@]}"; do
        try_command "$cmd"
    done

    echo ""
    echo "=== RDMA device rename completed ==="
    echo ""

    # Wait a moment for the system to stabilize
    sleep 2
else
    echo "=== RDMA device renaming skipped ==="
    echo ""
fi

# Network interface renaming section
declare -A ib_to_temp  # Mapping from IB device name to temporary name
counter=0

# Step 1: Rename to temporary names and record the mapping
echo "=== Step 1: Rename network interfaces to temporary names ==="
while read -r line; do
    ib_dev=$(echo "$line" | awk '{print $1}')
    net_name=$(echo "$line" | awk -F' ==> ' '{print $2}' | awk '{print $1}')

    temp_name="tmp_net_${counter}"

    echo "$net_name -> $temp_name (IB device: $ib_dev)"
    sudo ip link set "$net_name" down
    sudo ip link set "$net_name" name "$temp_name"

    # Save the mapping: IB device name -> temporary name
    ib_to_temp["$ib_dev"]="$temp_name"
    ((counter++))

done < <(ibdev2netdev)

# Step 2: Retrieve from ibdev2netdev again and rename to target names
echo ""
echo "=== Step 2: Rename to target network interface names ==="
while read -r line; do
    ib_dev=$(echo "$line" | awk '{print $1}')

    # Determine the target name based on IB device name
    if [[ "$ib_dev" =~ ^mezz_([0-9]+) ]]; then
        target_name="mezz_${BASH_REMATCH[1]}"
    elif [[ "$ib_dev" =~ ^mlx5_([0-9]+) ]]; then
        target_name="ib${BASH_REMATCH[1]}"
    else
        echo "Unknown device type: $ib_dev, skipping"
        continue
    fi

    # Get the temporary name from the mapping
    temp_name="${ib_to_temp[$ib_dev]}"

    if [[ -z "$temp_name" ]]; then
        echo "Error: Cannot find temporary name for $ib_dev"
        continue
    fi

    echo "$temp_name -> $target_name (IB device: $ib_dev)"
    sudo ip link set "$temp_name" down
    sudo ip link set "$temp_name" name "$target_name"
    sleep 1
    sudo ip link set "$target_name" up

done < <(ibdev2netdev)

echo ""
echo "=== All operations completed! ==="
echo ""
echo "=== Final result ==="
ibdev2netdev