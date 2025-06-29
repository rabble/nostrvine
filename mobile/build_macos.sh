#!/bin/bash
# ABOUTME: macOS build script that ensures CocoaPods dependencies are properly installed  
# ABOUTME: before building the macOS app to prevent pod install sync errors

set -e

echo "🖥️  Building macOS App..."

# Navigate to project root
cd "$(dirname "$0")"

# Ensure Flutter dependencies are up to date
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Navigate to macOS directory and install CocoaPods
echo "🏗️  Installing CocoaPods dependencies..."
cd macos

# Clean up any potential pod cache issues
if [ -d "Pods" ]; then
    echo "🧹 Cleaning existing Pods directory..."
    rm -rf Pods
fi

if [ -f "Podfile.lock" ]; then
    echo "🧹 Removing existing Podfile.lock..."
    rm -f Podfile.lock
fi

# Install pods
echo "📦 Running pod install..."
pod install

# Navigate back to project root
cd ..

# Build the macOS app
echo "🚀 Building macOS app..."
if [ "$1" = "release" ]; then
    flutter build macos --release
elif [ "$1" = "debug" ]; then
    flutter build macos --debug
else
    echo "Usage: $0 [debug|release]"
    echo "Building in debug mode by default..."
    flutter build macos --debug
fi

echo "✅ macOS build complete!"