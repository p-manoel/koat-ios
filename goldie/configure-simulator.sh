#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
capture_device="${1:?Informe o UDID do simulador de captura}"
xcrun simctl spawn "$capture_device" defaults write NSGlobalDomain AppleLanguages -array pt-BR
xcrun simctl spawn "$capture_device" defaults write NSGlobalDomain AppleLocale -string pt_BR
xcrun simctl spawn "$capture_device" defaults write Koat.Koat AppleLanguages -array pt-BR
xcrun simctl spawn "$capture_device" defaults write Koat.Koat AppleLocale -string pt_BR
xcrun simctl status_bar "$capture_device" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
