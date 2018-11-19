#!/bin/bash

echo "first test"
apt-get update

echo "[INFO]: installing dependencies"

echo "[INFO]: ifenslave installation for Ethernet link aggregation"

apt-get install -y ifenslave
