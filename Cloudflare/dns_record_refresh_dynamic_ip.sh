#!/bin/bash

# config

set -e

ENV_FILE=".env"

if [ -f ENV_FILE ]; then
  source "$ENV_FILE" # loadding up all the variables

else
  echo "Error: .env file doesnt exist"
  exit 1

fi

declare -A RECORDS

# it is a kind of map we use
# here we are mapping to the record_id of the dns

# COMMAND for getting the record if you dont know replace the ZONE_ID and API_TOKEN with your own
#########################################################################################################################
#curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/dns_records" -H "Authorization: Bearer <API_TOKEN> "\
# -H "Content-Type: application/json" | jq
###########################################################################################################################

RECORDS["vpn"]="$VPN"
RECORDS["media"]="$MEDIA"
RECORDS["ssh"]="$SSH"

# you can add the extra domain  based dns if you have , what i am doing is something [subdomain.domain] lets say you are setting up the
# jellyfin server for acessing over vpn (wireguard or tailscale ) from anywhere then for that you have created media.example.org
# [example.org --> domain]

WAN_IPV6=$(curl -6 -s ifconfig.co)

if [[ -z "$WAN_IPV6" ]]; then
  echo "could not detect WAN IPV6"
  exit 1
fi

echo "current WAN IPv6 : $WAN_IPV6"

for NAME in "${!RECORDS[@]}"; do
  RECORD_ID=${RECORDS[$NAME]}

  echo "Updating $NAME.necromancer-blog.xyz ..."
  # you can check the  cloudflare documenation for different api thing
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"AAAA\",\"name\":\"$NAME.$DOMAIN\",\"content\":\"$WAN_IPV6\",\"ttl\":1,\"proxied\":false}" |
    jq '.success,.errors,.messages'

done
