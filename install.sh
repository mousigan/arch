#!/bin/bash

set -euo pipefail

LOG_FILE="$HOME/arch_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=============================="
echo " Arch Production Installer"
echo "=============================="

# --- Safety check ---
if [ "$EUID" -eq 0 ]; then
  echo "❌ Do NOT run as root"
  exit 1
fi

# --- Internet check ---
echo "🌐 Checking internet..."
if ! ping -c 2 google.com &>/dev/null; then
  echo "❌ No internet connection"
  exit 1
fi

# --- Update system ---
echo "📦 Updating system..."
sudo pacman -Syu --noconfirm

# --- Detect GPU ---
echo "🖥️ Detecting GPU..."
GPU=$(lspci | grep -E "VGA|3D")

install_gpu_drivers() {
  if echo "$GPU" | grep -iq "nvidia"; then
    echo "➡️ NVIDIA detected"
    sudo pacman -S --needed --noconfirm nvidia nvidia-utils nvidia-settings
  elif echo "$GPU" | grep -iq "amd"; then
    echo "➡️ AMD detected"
    sudo pacman -S --needed --noconfirm mesa xf86-video-amdgpu vulkan-radeon
  elif echo "$GPU" | grep -iq "intel"; then
    echo "➡️ Intel detected"
    sudo pacman -S --needed --noconfirm mesa xf86-video-intel vulkan-intel
  else
    echo "⚠️ Unknown GPU, installing generic drivers"
    sudo pacman -S --needed --noconfirm mesa
  fi
}

install_gpu_drivers

# --- Base packages ---
echo "📦 Installing core packages..."
sudo pacman -S --needed --noconfirm \
  git base-devel \
  networkmanager \
  kitty neovim firefox nautilus \
  hyprland waybar wofi wlogout \
  xdg-desktop-portal-hyprland \
  wl-clipboard grim slurp \
  pipewire wireplumber \
  noto-fonts ttf-dejavu ttf-liberation \
  unzip zip imagemagick \
  xdg-user-dirs neofetch

# --- Enable services ---
echo "⚙️ Enabling services..."
sudo systemctl enable NetworkManager

# --- Clone repo ---
echo "📥 Cloning dotfiles..."
cd ~

if [ ! -d "Dotfiles" ]; then
  git clone https://github.com/VitorDelabenetta/Dotfiles.git
fi

cd Dotfiles/Arch-Linux || exit 1

# --- Backup old configs ---
echo "🛡️ Backing up existing configs..."
mkdir -p ~/.backup-dotfiles
cp -r ~/.config ~/.backup-dotfiles/ 2>/dev/null || true

# --- Create directories ---
mkdir -p ~/.config ~/.icons ~/.themes

# --- Apply configs safely ---
echo "⚙️ Applying configs..."

copy_if_exists() {
  SRC=$1
  DEST=$2
  if [ -e "$SRC" ]; then
    cp -r "$SRC" "$DEST"
  else
    echo "⚠️ Missing: $SRC"
  fi
}

copy_if_exists ".config/." ~/.config/
copy_if_exists ".icons/." ~/.icons/
copy_if_exists ".themes/." ~/.themes/

# --- Bashrc ---
if [ -f "system-folders/.bashrc" ]; then
  cp system-folders/.bashrc ~/
fi

# --- Neofetch config ---
if [ -f "system-folders/neofetch" ]; then
  mkdir -p ~/.config/neofetch
  cp system-folders/neofetch ~/.config/neofetch/config.conf
fi

# --- GRUB theme ---
if [ -d "system-folders/grub" ]; then
  echo "🎨 Installing GRUB theme..."
  sudo mkdir -p /boot/grub/themes
  sudo cp -r system-folders/grub /boot/grub/themes/
fi

# --- Install yay ---
echo "📦 Installing yay..."
if ! command -v yay &>/dev/null; then
  cd ~
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
fi

# --- AUR packages ---
echo "📦 Installing AUR packages..."
yay -S --needed --noconfirm \
  nerd-fonts-jetbrains-mono \
  google-chrome || true

# --- Enable display manager (Ly) ---
if [ -d "$HOME/Dotfiles/Arch-Linux/system-folders/ly" ]; then
  echo "🖥️ Installing Ly..."
  sudo pacman -S --needed --noconfirm ly
  sudo systemctl enable ly
fi

# --- Set default shell ---
echo "🐚 Setting bash as default shell..."
chsh -s /bin/bash

# --- Final checks ---
echo "🔍 Running final checks..."
if ! command -v hyprland &>/dev/null; then
  echo "❌ Hyprland install failed"
else
  echo "✅ Hyprland installed"
fi

# --- Done ---
echo "=============================="
echo "✅ INSTALL COMPLETE"
echo "📄 Log: $LOG_FILE"
echo "➡️ Reboot recommended"
echo "=============================="
