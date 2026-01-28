#!/bin/bash
for i in {1..6}; do openssl rand -base64 24 | tr -dc 'A-Z0-9' | head -c 24; echo; done
