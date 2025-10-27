#!/bin/sh

set -e

# Detect OS
os=$(uname -s)
case $os in
  Darwin)
    os="macos"
    ;;
  Linux)
    os="linux"
    ;;
  *)
    echo "Error: Unsupported operating system: $os"
    echo "Supported: macOS, Linux"
    exit 1
    ;;
esac

# Detect architecture
arch=$(uname -m)
case $arch in
  x86_64)
    if [ "$os" = "linux" ]; then
      arch="x86_64"
    fi
    ;;
  aarch64)
    if [ "$os" = "linux" ]; then
      arch="aarch64"
    fi
    ;;
  *)
    if [ "$os" = "linux" ]; then
      echo "Error: Unsupported architecture: $arch"
      echo "Supported: x86_64, aarch64"
      exit 1
    fi
    ;;
esac

# Ask for installation location
read -p "Install for all users? (y/n): " install_global

case $install_global in
  [Yy]*)
    install_dir="/usr/local/bin"
    use_sudo="sudo"
    ;;
  [Nn]*)
    install_dir="$HOME/.local/bin"
    use_sudo=""
    if [ ! -d "$install_dir" ]; then
      mkdir -p "$install_dir"
    fi
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Get latest version
latest_version=$(curl -s https://api.github.com/repos/savioruz/owi/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$latest_version" ]; then
  echo "Error: Could not fetch latest version"
  exit 1
fi

echo "Latest version: $latest_version"

# Build download URL
if [ "$os" = "macos" ]; then
  filename="owi-macos.tar.gz"
else
  filename="owi-linux-${arch}.tar.gz"
fi

download_url="https://github.com/savioruz/owi/releases/download/${latest_version}/${filename}"

# Download
temp_file=$(mktemp)

if command -v wget > /dev/null; then
  wget -q --show-progress -O "$temp_file" "$download_url"
elif command -v curl > /dev/null; then
  curl -L --progress-bar -o "$temp_file" "$download_url"
else
  echo "Error: Neither wget nor curl is available"
  exit 1
fi

# Verify download
if [ ! -s "$temp_file" ]; then
  echo "Error: Downloaded file is empty"
  rm -f "$temp_file"
  exit 1
fi

if ! file "$temp_file" | grep -q 'gzip compressed data'; then
  echo "Error: Downloaded file is not a valid gzip archive"
  rm -f "$temp_file"
  exit 1
fi

# Extract
echo "Installing to $install_dir..."
temp_dir=$(mktemp -d)
tar -xzf "$temp_file" -C "$temp_dir"

# Install binary
$use_sudo mv "$temp_dir/owi" "$install_dir/owi"
$use_sudo chmod +x "$install_dir/owi"

# Cleanup
rm -f "$temp_file"
rm -rf "$temp_dir"

echo "Installed: $install_dir/owi"

# Check if in PATH
if echo "$PATH" | grep -q "$install_dir"; then
  echo ""
  echo "You can now run: owi --help"
else
  echo ""
  echo "Note: $install_dir is not in your PATH"
  echo "Add this to your shell configuration (~/.bashrc, ~/.zshrc, etc.):"
  echo "  export PATH=\"$install_dir:\$PATH\""
fi
