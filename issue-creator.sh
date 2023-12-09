#!/bin/bash

# Check if figlet is installed
is_figlet_installed() {
    command -v figlet >/dev/null 2>&1 && echo "true" || echo "false"
}

# Function to get IP address of an interface
get_ip() {
    ip -4 addr show $1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
}

# Collects IP addresses of all network interfaces
collect_ips() {
    local ips=""
    for intf in $(ls /sys/class/net | grep -v lo); do
        local ip=$(get_ip $intf)
        [ ! -z "$ip" ] && ips+="${intf}: ${ip}, "
    done
    echo "${ips%, }" # Trim trailing comma
}

# Gets current date and time
get_datetime() {
    echo "$(date '+%Y-%m-%d') $(date '+%H:%M:%S')"
}

# Reads user status message
read_status_message() {
    read -p "Enter your status message: " user_status
    if [ "$user_status" == "01" ]; then
        echo "Proxmox Server running on a Dell Latitude 5020 Laptop - Intel i5 Processor - 64GB RAM"
    else
        echo "$user_status"
    fi
}

generate_hostname_string() {
    local hostname=$1
    local use_figlet=$2
    if [ "$use_figlet" == "true" ]; then
        figlet -w 160 $hostname
    else
        echo "Hostname: $hostname"
    fi
}

# Determines the longest line length
calculate_max_length() {
    local max_length=0
    for line in "$@"; do
        local length=${#line}
        (( length > max_length )) && max_length=$length
    done
    echo $max_length
}

create_banner() {
    # Get the current terminal width
    local terminal_width=$(tput cols)

    local max_content_length=0
    local line

    # Find the maximum content length
    for line in "$hostname_string" "$ips" "Date: $datetime" "Status: $status_message"; do
        (( ${#line} > max_content_length )) && max_content_length=${#line}
    done

    # Set frame width to the longest line plus 2 for padding, not exceeding terminal width
    local frame_width=$((max_content_length + 2))
    (( frame_width > terminal_width )) && frame_width=$terminal_width

    # Create extended frame line
    local extended_frame_line=$(printf '%*s' "$frame_width" | tr ' ' '*')

    # Function to print each line within the frame, centered
    print_frame_line() {
        local content_length=${#1}
        local padded_length=$(( (frame_width - content_length) / 2 ))
        printf "*%*s%-*s*\n" "$padded_length" "" "$((frame_width - padded_length - content_length - 1))" "$1"
    }

    # Print the top frame line
    echo "$extended_frame_line"

    # Print the hostname (figlet) centered
    if [ "$figlet_installed" == "true" ]; then
        echo "$hostname_string" | while IFS= read -r line; do
            print_frame_line "$line"
        done
    else
        print_frame_line "Hostname: $hostname"
    fi

    # Print a spacer line
    echo "$extended_frame_line"

    # Print the IP addresses
    print_frame_line "$ips"
    echo "$extended_frame_line"

    # Print the date and time
    print_frame_line "Date: $datetime"
    echo "$extended_frame_line"

    # Print the status message
    print_frame_line "Status: $status_message"
    echo "$extended_frame_line"
}


# Check if the script is running as root and save the banner accordingly
save_banner() {
    if [ "$EUID" -ne 0 ]; then
        local timestamp=$(date '+%Y%m%d-%H%M%S')
        local output_file="$HOME/issue-$timestamp"
        create_banner > "$output_file"
        cat "$output_file"
    else
        create_banner > /etc/issue
        cat "/etc/issue"
    fi
}
# Main function
main() {
    local hostname=$(hostname)
    local figlet_installed=$(is_figlet_installed)
    local hostname_string=$(generate_hostname_string "$hostname" "$figlet_installed")
    local ips=$(collect_ips)
    local datetime=$(get_datetime)
    local status_message=$(read_status_message)

    # Calculate max length for non-figlet content
    local max_length_non_figlet=$(calculate_max_length "$ips" "Date: $datetime" "Status: $status_message")
    
    # Calculate max length for figlet content
    local max_length_figlet=0
    if [ "$figlet_installed" == "true" ]; then
        IFS=$'\n'
        for line in $hostname_string; do
            local length=${#line}
            (( length > max_length_figlet )) && max_length_figlet=$length
        done
        unset IFS
    else
        max_length_figlet=$max_length_non_figlet
    fi

    # Determine the overall maximum length
    local max_length=$(( max_length_non_figlet > max_length_figlet ? max_length_non_figlet : max_length_figlet ))

    save_banner
}

# Run the main function
main

