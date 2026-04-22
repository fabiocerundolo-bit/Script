#!/bin/bash
BASE_URL="https://raw.githubusercontent.com/fabiocerundolo-bit/Script/main"

# Scarica i moduli
curl -sL "$BASE_URL/pacchetti.sh" -o pacchetti.sh
curl -sL "$BASE_URL/niri_config.sh" -o niri_config.sh

# Eseguili
chmod +x *.sh
./pacchetti.sh
./niri_config.sh
