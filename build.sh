#!/bin/sh
# Build BOOPBOT on QNX SDP 8.0
set -e
cd "$(dirname "$0")"
cmake . -DCMAKE_PREFIX_PATH=/usr/lib/cmake/Qt6 -DCMAKE_BUILD_TYPE=Release
make -j4
echo ""
echo "Build complete. Run with: ./run.sh"
