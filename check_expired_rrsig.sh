#!/bin/bash

# Function to convert RRSIG expiration date to seconds since epoch
convert_to_epoch() {
  date_str=$1
  date -u -d "${date_str:0:4}-${date_str:4:2}-${date_str:6:2} ${date_str:8:2}:${date_str:10:2}:${date_str:12:2}" +"%s" 2>/dev/null
}

# Function to send a notification to the 'admin' DirectAdmin user
send_notification() {
  subject=$1
  message=$2
  task="action=notify&value=admin&subject=$subject&message=$message&users=select1=admin"
  echo $task >> /usr/local/directadmin/data/task.queue
  echo "Notification sent to admin administrator"
}

# Function to check for expired or soon-to-expire RRSIGs in a given zone file
check_expired_rrsig() {
  zone_file=$1
  debug=$2
  current_time=$(date -u +"%s")
  one_day_later=$((current_time + 86400))

  domain_name=$(basename "$zone_file" .db.signed)

  echo "Checking zone file: $zone_file"

  # Flags and counters
  in_rrsig=false
  valid_count=0
  expired_count=0
  invalid_count=0
  expiring_soon_count=0
  message=""

  while read -r line; do
    # Check if the line contains "RRSIG" and start capturing the RRSIG record
    if [[ $line == *"RRSIG"* ]]; then
      in_rrsig=true
      continue
    fi

    # If we are in an RRSIG record, capture the expiration date from the next line
    if $in_rrsig; then
      expiration_date=$(echo $line | awk '{print $1}')
      in_rrsig=false

      # Convert expiration date to epoch
      expiration_epoch=$(convert_to_epoch $expiration_date)

      # Check if the date conversion was successful
      if [[ -z "$expiration_epoch" ]]; then
        echo "Invalid expiration date: $expiration_date"
        ((invalid_count++))
        continue
      fi

      # Compare the expiration epoch with the current time
      if (( expiration_epoch < current_time )); then
        echo "Expired RRSIG found:"
        echo "$line"
        message+="Expired RRSIG found in $zone_file:\n$line\n\n"
        ((expired_count++))
      elif (( expiration_epoch < one_day_later )); then
        echo "RRSIG expiring soon found:"
        echo "$line"
        message+="RRSIG expiring within 24 hours in $zone_file:\n$line\n\n"
        ((expiring_soon_count++))
      else
        ((valid_count++))
        if [[ "$debug" == "true" ]]; then
          echo "Valid RRSIG:"
          echo "$line"
        fi
      fi
    fi
  done < "$zone_file"

  echo "Summary for $zone_file:"
  echo "Valid RRSIGs: $valid_count"
  echo "Expired RRSIGs: $expired_count"
  echo "Expiring Soon RRSIGs: $expiring_soon_count"
  echo "Invalid RRSIGs: $invalid_count"

  tally_message="Summary for $zone_file:\nValid RRSIGs: $valid_count\nExpired RRSIGs: $expired_count\nExpiring Soon RRSIGs: $expiring_soon_count\nInvalid RRSIGs: $invalid_count\n\n"
  message="$tally_message$message"
  encoded_message=$(echo -e "$message" | sed ':a;N;$!ba;s/\n/%0A/g')

  # Determine the reason for the notification
  reason=""
  if [[ "$debug" == "true" ]]; then
    reason="Debug Mode"
  fi
  if [[ $expired_count -gt 0 ]]; then
    reason="${reason} Expired: $expired_count "
  fi
  if [[ $expiring_soon_count -gt 0 ]]; then
    reason="${reason} Expiring Soon: $expiring_soon_count "
  fi
  if [[ $invalid_count -gt 0 ]]; then
    reason="${reason} Invalid: $invalid_count "
  fi
  if [[ $valid_count -gt 0 ]]; then
    reason="${reason} Valid: $valid_count "
  fi

  # Send notification if conditions are met
  if [[ "$debug" == "true" || $expired_count -gt 0 || $invalid_count -gt 0 || $expiring_soon_count -gt 0 ]]; then
    send_notification "RRSIG Notification for $domain_name - $reason" "$encoded_message"
  fi
}

# Directory containing DNS zone files (modify as needed)
zone_files_dir="/var/named"

# Check if a specific zone file is provided as an argument
if [[ -n $1 ]]; then
  zone_file="$zone_files_dir/$1.db.signed"
  if [[ -f $zone_file ]]; then
    check_expired_rrsig "$zone_file" "$2"
  else
    echo "Zone file $zone_file does not exist."
    exit 1
  fi
else
  # Loop through all signed zone files in the directory if no argument is provided
  for zone_file in "$zone_files_dir"/*.db.signed; do
    if [[ -f $zone_file ]]; then
      check_expired_rrsig "$zone_file" "$1"
    fi
  done
fi