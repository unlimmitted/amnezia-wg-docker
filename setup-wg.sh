#!/bin/bash

INPUT_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep '^eth' | head -n 1)

if [ -z "$INPUT_INTERFACE" ]; then
  exit 1
fi

wg-quick up wg1

iptables-legacy -A FORWARD -i wg1 -o wg0 -j ACCEPT
iptables-legacy -A FORWARD -i wg0 -o wg1 -j ACCEPT
iptables-legacy -t nat -A POSTROUTING -o wg0 -j MASQUERADE
iptables-legacy -t nat -A POSTROUTING -o $INPUT_INTERFACE -j MASQUERADE

exec /sbin/init
