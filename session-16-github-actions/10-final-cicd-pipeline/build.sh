#!/bin/bash
set -e
echo "================================="
echo "Starting Application Build"
echo "================================="
rm -rf build
mkdir -p build/app
cp app/__init__.py app/calculator.py app/server.py build/app/
cat > build/build-info.txt <<INFO
Application: Session 16 Calculator
Build Status: SUCCESS
Commit: ${GITHUB_SHA:-local}
Build Date: $(date)
INFO
echo ""
echo "Build files:"
ls -la build build/app
echo ""
echo "Build completed successfully."
