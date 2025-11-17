#!/bin/bash

# Function to check device mapping with detailed reporting
check_device_mapping() {
    echo "=== Checking RDMA device to network interface mapping ==="
    echo ""

    local all_correct=true
    local mezz_mismatched=()
    local mlx5_mismatched=()
    local other_mismatched=()

    # Counters for statistics
    local total_devices=0
    local matched_devices=0
    local mismatched_devices=0

    # Read ibdev2netdev output and check each line
    while read -r line; do
        ((total_devices++))

        # Extract IB device name, network interface name, and status
        ib_dev=$(echo "$line" | awk '{print $1}')
        net_name=$(echo "$line" | awk -F' ==> ' '{print $2}' | awk '{print $1}')
        status=$(echo "$line" | grep -oP '\((Up|Down)\)' | tr -d '()')

        # Check if IB device name matches network interface name
        if [ "$ib_dev" = "$net_name" ]; then
            echo "✓ $ib_dev -> $net_name [$status] (MATCHED)"
            ((matched_devices++))
        else
            echo "✗ $ib_dev -> $net_name [$status] (MISMATCHED)"
            ((mismatched_devices++))
            all_correct=false

            # Categorize mismatched devices
            if [[ "$ib_dev" =~ ^mezz_ ]]; then
                mezz_mismatched+=("$ib_dev -> $net_name")
            elif [[ "$ib_dev" =~ ^mlx5_ ]]; then
                mlx5_mismatched+=("$ib_dev -> $net_name")
            else
                other_mismatched+=("$ib_dev -> $net_name")
            fi
        fi
    done < <(ibdev2netdev)

    echo ""
    echo "=== Check Summary ==="
    echo "Total devices: $total_devices"
    echo "Matched: $matched_devices"
    echo "Mismatched: $mismatched_devices"
    echo ""

    if [ "$all_correct" = true ]; then
        echo "✓ All device mappings are correct!"
        return 0
    else
        echo "✗ Found mismatched device mappings:"
        echo ""

        if [ ${#mezz_mismatched[@]} -gt 0 ]; then
            echo "Mismatched mezz devices:"
            for device in "${mezz_mismatched[@]}"; do
                echo "  - $device"
            done
            echo ""
        fi

        if [ ${#mlx5_mismatched[@]} -gt 0 ]; then
            echo "Mismatched mlx5 devices:"
            for device in "${mlx5_mismatched[@]}"; do
                echo "  - $device"
            done
            echo ""
        fi

        if [ ${#other_mismatched[@]} -gt 0 ]; then
            echo "Other mismatched devices:"
            for device in "${other_mismatched[@]}"; do
                echo "  - $device"
            done
            echo ""
        fi

        return 1
    fi
}

# Run the check
check_device_mapping
exit_code=$?

echo ""
if [ $exit_code -eq 0 ]; then
    echo "Recommendation: No action needed."
else
    echo "Recommendation: Run rdma-netdev-rename.sh to fix the mapping."
fi

exit $exit_code