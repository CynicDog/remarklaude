#!/bin/sh
# connect.sh — run this from inside a terminal app on the reMarkable
# (fingerterm, ReTerm, ...) to open remarklaude on the host machine.
#
# Copy this onto the device, e.g.:
#   scp remarkable/connect.sh root@10.11.99.1:/home/root/connect-claude.sh
#
# Then, on the reMarkable, set REMARKLAUDE_HOST once (e.g. in .bashrc)
# or just edit the default below to your Mac's hostname/IP.
HOST="${REMARKLAUDE_HOST:-yourmac.local}"
exec ssh -t "$HOST" remarklaude
