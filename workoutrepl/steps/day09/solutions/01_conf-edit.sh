#!/usr/bin/env bash
sed -i.bak -e 's/^debug = false$/debug = true/' \
           -e 's/^;port = 8080$/port = 9090/' \
           -e '/^[#;].*deprecated/d' \
           -e '/^\[server\]$/a max_conn = 100' app.conf
