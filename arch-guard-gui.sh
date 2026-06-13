#!/usr/bin/env bash

# Configurazione rigorosa per la massima sicurezza e gestione errori
set -euo pipefail

# Elenco dei pacchetti infetti (Arch Linux HedgeDoc ufficiale)
LIST_URL="https://md.archlinux.org/s/SxbqukK6IA"

# Verifica che pacman e zenity siano installati
if ! command -v pacman &> /dev/null; then
    echo "ERRORE: Pacman non trovato. Questo script richiede una base Arch Linux." >&2
    exit 1
fi

if ! command -v zenity &> /dev/null; then
    echo "Zenity non trovato. Tento l'installazione automatica..."
    sudo pacman -S --noconfirm zenity
fi

# 1. Finestra di avanzamento (Scansione in corso)
(
    echo "10" ; echo "# Identificazione del sistema operativo..." ; sleep 0.3
    distro=$(grep -P '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')

    echo "40" ; echo "# Connessione al database di sicurezza Arch Linux..."
    raw=$(curl -fsSL "$LIST_URL") || { echo "ERRORE" > /tmp/scan_err; exit 1; }

    echo "70" ; echo "# Analisi delle firme malware di Arch..."
    mapfile -t INFECTED_PKGS < <(
        echo "$raw" |
        sed 's/<[^>]*>//g' |
        grep -E '^[a-z0-9][a-z0-9_.+\-]*[a-z0-9]$' |
        sort -u
    )

    count=${#INFECTED_PKGS[@]}
    if [[ $count -eq 0 ]]; then
        echo "ERRORE_PARSE" > /tmp/scan_err
        exit 1
    fi

    printf "%s\n" "${INFECTED_PKGS[@]}" > /tmp/infected_list.txt

    echo "90" ; echo "# Controllo incrociato dei pacchetti locali..."
    mapfile -t installed < <(pacman -Qq | sort)
    mapfile -t found < <(comm -12 <(printf "%s\n" "${installed[@]}") /tmp/infected_list.txt)

    printf "%s\n" "${found[@]}" > /tmp/scan_result.txt
    echo "100" ; echo "# Analisi completata con successo!" ; sleep 0.3
) | zenity --progress --title="Arch Guard v1.0.0" --text="Inizializzazione scansione..." --percentage=0 --auto-close --no-cancel

# Gestione degli errori durante la pipeline di rete/parsing
if [[ -f /tmp/scan_err ]]; then
    err_type=$(cat /tmp/scan_err)
    rm -f /tmp/scan_err
    if [[ "$err_type" == "ERRORE_PARSE" ]]; then
        zenity --error --title="Errore Database" --text="Impossibile leggere la lista. Il formato dell'HedgeDoc potrebbe essere cambiato." --width=400
    else
        zenity --error --title="Errore di Rete" --text="Impossibile raggiungere $LIST_URL\nVerifica la tua connessione a Internet." --width=400
    fi
    exit 1
fi

# Lettura dei risultati generati
mapfile -t found < /tmp/scan_result.txt
rm -f /tmp/scan_result.txt /tmp/infected_list.txt

# 2. Resoconto finale all'utente
if [[ ${#found[@]} -eq 0 || ( ${#found[@]} -eq 1 && -z "${found}" ) ]]; then
    zenity --info \
        --title="Sistema Sicuro - Arch Guard" \
        --text="✅ <b>Il tuo sistema è pulito!</b>\n\nNessuno dei pacchetti compromessi segnalati dal team di Arch Linux risulta installato." \
        --width=450
else
    pkg_text=""
    for pkg in "${found[@]}"; do
        if [[ -n "$pkg" ]]; then
            pkg_text+="• <span foreground='red'><b>$pkg</b></span>\n"
        fi
    done

    zenity --warning \
        --title="⚠️ PERICOLO: Trovate Minacce!" \
        --text="❌ <b>ATTENZIONE! Rilevati pacchetti infetti sul sistema:</b>\n\n$pkg_text\nSi consiglia di rimuoverli immediatamente eseguendo nel terminale:\n<code>sudo pacman -Rns &lt;nome_pacchetto&gt;</code>" \
        --width=500
    exit 2
fi
