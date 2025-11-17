#!/bin/bash

# Function to check if device mappings are correct
check_device_mapping() {
    echo "=== Checking RDMA device to network interface mapping ==="
    echo ""

    local all_correct=true
    local mismatched_devices=()

    # Read ibdev2netdev output and check each line
    while read -r line; do
        # Extract IB device name and network interface name
        ib_dev=$(echo "$line" | awk '{print $1}')
        net_name=$(echo "$line" | awk -F' ==> ' '{print $2}' | awk '{print $1}')
        status=$(echo "$line" | grep -oP '\((Up|Down)\)' | tr -d '()')

        # Determine expected network interface name
        if [[ "$ib_dev" =~ ^mezz_([0-9]+)$ ]]; then
            # For mezz_X, expected name is mezz_X (same as IB device)
            expected_net="mezz_${BASH_REMATCH[1]}"
        elif [[ "$ib_dev" =~ ^mlx5_([0-9]+)$ ]]; then
            # For mlx5_X, expected name is ibX
            expected_net="ib${BASH_REMATCH[1]}"
        else
            # Unknown device type, skip
            echo "? $ib_dev -> $net_name [$status] (UNKNOWN TYPE)"
            continue
        fi

        # Check if actual matches expected
        if [ "$net_name" = "$expected_net" ]; then
            echo "✓ $ib_dev -> $net_name [$status] (CORRECT)"
        else
            echo "✗ $ib_dev -> $net_name [$status] (Expected: $expected_net)"
            all_correct=false
            mismatched_devices+=("$ib_dev -> $net_name (Expected: $expected_net)")
        fi
    done < <(ibdev2netdev)

    echo ""
    echo "=== Check Summary ==="
    if [ "$all_correct" = true ]; then
        echo "✓ All device mappings are correct!"
        return 0
    else
        echo "✗ Found mismatched device mappings:"
        for device in "${mismatched_devices[@]}"; do
            echo "  - $device"
        done
        return 1
    fi
}

# Run the check
check_device_mapping
exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo "No action needed."
else
    echo "Recommendation: Run rdma-netdev-rename.sh to fix the mapping."
fi

exit $exit_code
