#!/bin/bash

set -e

# Configuration
PROJECT_NAME="CatchStalker"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
SCHEME="${PROJECT_NAME}"
CONFIGURATION="Release"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Parse arguments
BUILD_TYPE="debug"
CLEAN=false
ARCHIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            CONFIGURATION="Release"
            shift
            ;;
        --debug)
            BUILD_TYPE="debug"
            CONFIGURATION="Debug"
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --archive)
            ARCHIVE=true
            BUILD_TYPE="release"
            CONFIGURATION="Release"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug     Build debug configuration (default)"
            echo "  --release   Build release configuration"
            echo "  --clean     Clean before building"
            echo "  --archive   Create an archive for distribution"
            echo "  --help, -h  Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    print_error "xcodebuild not found. Please install Xcode."
    exit 1
fi

# Print build info
echo ""
echo "======================================"
echo "  ${PROJECT_NAME} Build Script"
echo "======================================"
echo "Configuration: ${CONFIGURATION}"
echo "Build Type: ${BUILD_TYPE}"
echo ""

# Clean if requested
if [ "$CLEAN" = true ]; then
    print_step "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
    xcodebuild clean \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -quiet
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

if [ "$ARCHIVE" = true ]; then
    # Archive build for distribution
    print_step "Creating archive..."
    xcodebuild archive \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -archivePath "${ARCHIVE_PATH}" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO

    print_step "Archive created at: ${ARCHIVE_PATH}"
    
    # Check if export options plist exists
    if [ -f "ExportOptions.plist" ]; then
        print_step "Exporting archive..."
        xcodebuild -exportArchive \
            -archivePath "${ARCHIVE_PATH}" \
            -exportPath "${EXPORT_PATH}" \
            -exportOptionsPlist "ExportOptions.plist"
        
        print_step "Exported to: ${EXPORT_PATH}/${PROJECT_NAME}.app"
    else
        print_warning "ExportOptions.plist not found. Skipping export."
        print_warning "To export, create ExportOptions.plist or manually export from Xcode."
    fi
else
    # Regular build
    print_step "Building ${PROJECT_NAME} (${CONFIGURATION})..."
    xcodebuild build \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO

    # Find and report the built app
    APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${PROJECT_NAME}.app" -type d | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo ""
        print_step "Build successful!"
        echo "App location: ${APP_PATH}"
        echo ""
        echo "To run the app:"
        echo "  open \"${APP_PATH}\""
    else
        print_error "Build completed but app not found"
        exit 1
    fi
fi

echo ""
echo "======================================"
echo "  Build Complete"
echo "======================================"
