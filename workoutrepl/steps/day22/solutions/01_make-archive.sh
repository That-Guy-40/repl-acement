#!/usr/bin/env bash
tar -czf site.tar.gz --exclude='*.log' --exclude='site/cache' -C . site
