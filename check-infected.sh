#!/usr/bin/env bash

# Configurazione rigorosa per la massima sicurezza e gestione errori
set -euo pipefail

# Elenco dei pacchetti infetti (Arch Linux HedgeDoc ufficiale)
LIST_URL="https://archlinux.org"

# Verifica che pacman sia installato (controllo per distribuzioni derivate)
if ! command -v pacman &> /dev/null; then
    echo "ERRORE: Questo script funziona solo su distribuzioni basate su Arch Linux (pacman non trovato)." >&2
    exit 1
fi

echo "=== Rilevamento Pacchetti Compromessi ==="
echo "Distribuzione: $(grep -P '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')"
echo "Download della lista dei pacchetti infetti..."

# Scarica la pagina gestendo i fallimenti della rete
raw=$(curl -fsSL "$LIST_URL") || { echo "ERRORE: Impossibile scaricare la lista da $LIST_URL" >&2; exit 1; }

echo "Analisi dei dati in corso..."

# Estrae i pacchetti pulendo l'HTML e filtrando i nomi validi
mapfile -t INFECTED_PKGS < <(
    echo "$raw" |
    sed 's/<[^>]*>//g' |
    grep -E '^[a-z0-9][a-z0-9_.+\-]*[a-z0-9]$' |
    sort -u
)

count=${#INFECTED_PKGS[@]}
if [[ $count -eq 0 ]]; then
    echo "ERRORE: Trovati 0 pacchetti nella lista. Il formato del sito potrebbe essere cambiato." >&2
    exit 1
fi

echo "Controllo di $count pacchetti infetti rispetto al tuo sistema..."
echo

# Verifica TUTTI i pacchetti locali (inclusi quelli nativi e quelli AUR/esterni)
mapfile -t installed < <(pacman -Qq | sort)

# Trova l'intersezione tra i pacchetti installati e quelli infetti
mapfile -t found < <(comm -12 <(printf "%s\n" "${installed[@]}") <(printf "%s\n" "${INFECTED_PKGS[@]}"))

if [[ ${#found[@]} -eq 0 ]]; then
    echo "✅ SISTEMA PULITO: Nessuno dei pacchetti infetti noti è installato."
else
    echo "❌ ATTENZIONE: Sono stati trovati ${#found[@]} pacchetti infetti!"
    echo "----------------------------------------------------"
    for pkg in "${found[@]}"; do
        echo "  - $pkg"
    done
    echo "----------------------------------------------------"
    echo "IL TUO SISTEMA POTREBBE ESSERE STATO COMPROMESSO."
    echo "Si consiglia di rimuoverli immediatamente con: sudo pacman -Rns <nome_pacchetto>"

    # Invia una notifica desktop se l'ambiente grafico è attivo e notify-send è installato
    if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send &> /dev/null; then
        notify-send -u critical "ALLERTA SICUREZZA" "Trovati ${#found[@]} pacchetti infetti installati nel sistema!"
    fi

    exit 2
fi
