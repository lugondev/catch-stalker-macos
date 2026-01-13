#!/bin/bash

set -e

PROJECT_NAME="CatchStalker"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
SCHEME="${PROJECT_NAME}"
BUILD_DIR="build"
RELEASE_DIR="${BUILD_DIR}/release"
DMG_NAME="${PROJECT_NAME}.dmg"
ZIP_NAME="${PROJECT_NAME}.zip"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}==>${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Create a GitHub release for ${PROJECT_NAME}

Options:
  -v, --version VERSION   Version number (e.g., 1.0.0) - REQUIRED
  -t, --tag TAG           Git tag name (default: v<version>)
  -m, --message MSG       Release title/message
  -n, --notes FILE        Release notes file (default: generates from commits)
  -p, --prerelease        Mark as pre-release
  -d, --draft             Create as draft release
      --no-dmg            Skip DMG creation
      --no-zip            Skip ZIP creation
      --skip-build        Skip building (use existing build)
      --dry-run           Show what would be done without executing
  -h, --help              Show this help

Examples:
  $0 -v 1.0.0
  $0 -v 1.0.0 -m "Initial Release" -p
  $0 -v 2.0.0 -n CHANGELOG.md
EOF
}

check_dependencies() {
    local missing=()
    
    if ! command -v gh &> /dev/null; then
        missing+=("gh (GitHub CLI)")
    fi
    
    if ! command -v xcodebuild &> /dev/null; then
        missing+=("xcodebuild (Xcode)")
    fi
    
    if ! command -v hdiutil &> /dev/null; then
        missing+=("hdiutil")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI not authenticated. Run: gh auth login"
        exit 1
    fi
}

get_version_from_project() {
    local version
    version=$(grep -A1 "MARKETING_VERSION" "${PROJECT_FILE}/project.pbxproj" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    echo "$version"
}

update_version_in_project() {
    local new_version=$1
    print_step "Updating version to ${new_version} in Xcode project..."
    
    sed -i '' "s/MARKETING_VERSION = [0-9]*\.[0-9]*\.[0-9]*/MARKETING_VERSION = ${new_version}/g" "${PROJECT_FILE}/project.pbxproj"
}

build_release() {
    print_step "Building release..."
    
    rm -rf "${RELEASE_DIR}"
    mkdir -p "${RELEASE_DIR}"
    
    xcodebuild build \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        -quiet
    
    local app_path
    app_path=$(find "${BUILD_DIR}/DerivedData" -name "${PROJECT_NAME}.app" -type d | head -1)
    
    if [ -z "$app_path" ]; then
        print_error "Build failed: ${PROJECT_NAME}.app not found"
        exit 1
    fi
    
    cp -R "$app_path" "${RELEASE_DIR}/"
    print_info "Built: ${RELEASE_DIR}/${PROJECT_NAME}.app"
}

create_dmg() {
    local version=$1
    local dmg_path="${RELEASE_DIR}/${PROJECT_NAME}-${version}.dmg"
    local temp_dmg="${RELEASE_DIR}/temp.dmg"
    local mount_point="${RELEASE_DIR}/dmg_mount"
    
    print_step "Creating DMG..."
    
    rm -f "$dmg_path" "$temp_dmg"
    mkdir -p "$mount_point"
    
    local dmg_size
    dmg_size=$(du -sm "${RELEASE_DIR}/${PROJECT_NAME}.app" | cut -f1)
    dmg_size=$((dmg_size + 50))
    
    hdiutil create -size "${dmg_size}m" -fs HFS+ -volname "${PROJECT_NAME}" "$temp_dmg" -quiet
    
    hdiutil attach "$temp_dmg" -mountpoint "$mount_point" -quiet
    
    cp -R "${RELEASE_DIR}/${PROJECT_NAME}.app" "$mount_point/"
    ln -s /Applications "$mount_point/Applications"
    
    if [ -f "images/logo.png" ]; then
        cp "images/logo.png" "$mount_point/.VolumeIcon.icns" 2>/dev/null || true
    fi
    
    if [ -f "images/dmg_background.png" ]; then
        mkdir -p "$mount_point/.background"
        cp "images/dmg_background.png" "$mount_point/.background/background.png"
    fi
    
    hdiutil detach "$mount_point" -quiet
    
    hdiutil convert "$temp_dmg" -format UDZO -o "$dmg_path" -quiet
    
    rm -f "$temp_dmg"
    rmdir "$mount_point" 2>/dev/null || true
    
    print_info "Created: $dmg_path"
    echo "$dmg_path"
}

create_zip() {
    local version=$1
    local zip_path="${RELEASE_DIR}/${PROJECT_NAME}-${version}.zip"
    
    print_step "Creating ZIP..."
    
    rm -f "$zip_path"
    
    (cd "${RELEASE_DIR}" && zip -r -q "$(basename "$zip_path")" "${PROJECT_NAME}.app")
    
    print_info "Created: $zip_path"
    echo "$zip_path"
}

generate_release_notes() {
    local version=$1
    local notes_file="${RELEASE_DIR}/release_notes.md"
    
    print_step "Generating release notes..."
    
    cat > "$notes_file" << EOF
## ${PROJECT_NAME} v${version}

### Installation

1. Download \`${PROJECT_NAME}-${version}.dmg\` or \`${PROJECT_NAME}-${version}.zip\`
2. For DMG: Open and drag ${PROJECT_NAME} to Applications
3. For ZIP: Extract and move ${PROJECT_NAME}.app to Applications
4. Launch ${PROJECT_NAME} from Applications
5. Grant required permissions when prompted

### System Requirements

- macOS 13.0 (Ventura) or later
- Required permissions: Accessibility, Screen Recording, Camera

### Features

- Keystroke and mouse activity logging
- Periodic screenshot and camera capture
- Application usage tracking
- File access and clipboard monitoring
- Anti-sleep with scheduled rules
- Local-only data storage

EOF

    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    if [ -n "$last_tag" ]; then
        echo "### Changes since ${last_tag}" >> "$notes_file"
        echo "" >> "$notes_file"
        git log "${last_tag}..HEAD" --pretty=format:"- %s" 2>/dev/null >> "$notes_file" || true
        echo "" >> "$notes_file"
    fi
    
    cat >> "$notes_file" << EOF

---

<p align="center">
  <img src="https://github.com/$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "user/repo")/raw/main/images/app.jpeg" width="600">
</p>

> **Privacy Notice**: All data is stored locally on your device and is never transmitted externally.
EOF

    print_info "Generated: $notes_file"
    echo "$notes_file"
}

create_github_release() {
    local version=$1
    local tag=$2
    local title=$3
    local notes_file=$4
    local prerelease=$5
    local draft=$6
    local assets=("${@:7}")
    
    print_step "Creating GitHub release..."
    
    local release_args=("--title" "$title" "--notes-file" "$notes_file")
    
    if [ "$prerelease" = true ]; then
        release_args+=("--prerelease")
    fi
    
    if [ "$draft" = true ]; then
        release_args+=("--draft")
    fi
    
    for asset in "${assets[@]}"; do
        if [ -f "$asset" ]; then
            release_args+=("$asset")
        fi
    done
    
    if ! git rev-parse "$tag" &>/dev/null; then
        print_step "Creating tag ${tag}..."
        git tag -a "$tag" -m "Release ${version}"
        git push origin "$tag"
    else
        print_info "Tag ${tag} already exists"
    fi
    
    gh release create "$tag" "${release_args[@]}"
    
    local release_url
    release_url=$(gh release view "$tag" --json url -q .url)
    print_info "Release URL: $release_url"
}

VERSION=""
TAG=""
MESSAGE=""
NOTES_FILE=""
PRERELEASE=false
DRAFT=false
CREATE_DMG=true
CREATE_ZIP=true
SKIP_BUILD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -m|--message)
            MESSAGE="$2"
            shift 2
            ;;
        -n|--notes)
            NOTES_FILE="$2"
            shift 2
            ;;
        -p|--prerelease)
            PRERELEASE=true
            shift
            ;;
        -d|--draft)
            DRAFT=true
            shift
            ;;
        --no-dmg)
            CREATE_DMG=false
            shift
            ;;
        --no-zip)
            CREATE_ZIP=false
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    print_error "Version is required. Use -v or --version"
    echo ""
    show_help
    exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Use semantic versioning (e.g., 1.0.0)"
    exit 1
fi

[ -z "$TAG" ] && TAG="v${VERSION}"
[ -z "$MESSAGE" ] && MESSAGE="${PROJECT_NAME} ${VERSION}"

echo ""
echo "======================================"
echo "  ${PROJECT_NAME} Release Script"
echo "======================================"
echo "Version:     ${VERSION}"
echo "Tag:         ${TAG}"
echo "Title:       ${MESSAGE}"
echo "Pre-release: ${PRERELEASE}"
echo "Draft:       ${DRAFT}"
echo "Create DMG:  ${CREATE_DMG}"
echo "Create ZIP:  ${CREATE_ZIP}"
echo "======================================"
echo ""

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN - No changes will be made"
    echo ""
    echo "Would perform:"
    echo "  1. Update version to ${VERSION}"
    echo "  2. Build release"
    [ "$CREATE_DMG" = true ] && echo "  3. Create DMG"
    [ "$CREATE_ZIP" = true ] && echo "  4. Create ZIP"
    echo "  5. Create GitHub release with tag ${TAG}"
    exit 0
fi

check_dependencies

if [ -n "$(git status --porcelain)" ]; then
    print_warning "Working directory has uncommitted changes"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

current_version=$(get_version_from_project)
if [ "$current_version" != "$VERSION" ]; then
    update_version_in_project "$VERSION"
fi

if [ "$SKIP_BUILD" = false ]; then
    build_release
else
    print_info "Skipping build (--skip-build)"
    if [ ! -d "${RELEASE_DIR}/${PROJECT_NAME}.app" ]; then
        print_error "No existing build found at ${RELEASE_DIR}/${PROJECT_NAME}.app"
        exit 1
    fi
fi

ASSETS=()

if [ "$CREATE_DMG" = true ]; then
    dmg_path=$(create_dmg "$VERSION")
    ASSETS+=("$dmg_path")
fi

if [ "$CREATE_ZIP" = true ]; then
    zip_path=$(create_zip "$VERSION")
    ASSETS+=("$zip_path")
fi

if [ -z "$NOTES_FILE" ]; then
    NOTES_FILE=$(generate_release_notes "$VERSION")
elif [ ! -f "$NOTES_FILE" ]; then
    print_error "Notes file not found: $NOTES_FILE"
    exit 1
fi

create_github_release "$VERSION" "$TAG" "$MESSAGE" "$NOTES_FILE" "$PRERELEASE" "$DRAFT" "${ASSETS[@]}"

echo ""
echo "======================================"
echo "  Release Complete!"
echo "======================================"
echo ""
print_info "Version ${VERSION} has been released"
print_info "Assets uploaded:"
for asset in "${ASSETS[@]}"; do
    echo "  - $(basename "$asset")"
done
