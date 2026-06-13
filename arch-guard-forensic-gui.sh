#!/usr/bin/env bash
# Arch Guard v2.0.0 - Forensic & IOC Scanner
set -uo pipefail

IOC_NAMES='atomic-lockfile|js-digest|lockfile-js|src/hooks/deps'
PM_ACTION='(^|[^[:alnum:]_/-])(npm|npx|pnpm|yarn|bun|bunx)[[:space:]]'
CAMPAIGN_START='2026-06-09'
LIST_URL="${ATOMIC_LIST_URL:-https://md.archlinux.org/s/SxbqukK6IA/download}"

# Controllo dipendenze grafiche
if ! command -v zenity &> /dev/null; then
    echo "ERRORE: Zenity non è installato. Installalo con: sudo pacman -S zenity" >&2
    exit 1
fi

LOG_FILE="/tmp/arch_guard_scan.log"
echo "=== LOG DI SCANSIONE ARCH GUARD FORENSIC ===" > "$LOG_FILE"
echo "Data: $(date)" >> "$LOG_FILE"

# 1. Recupero Caches AUR
xch="${XDG_CACHE_HOME:-$HOME/.cache}"
xdh="${XDG_DATA_HOME:-$HOME/.local/share}"
caches=()
for d in "$xch/yay" "$xch/paru" "$xdh/pikaur/aur_repos" "$xch/pikaur/aur_repos" "$xch/trizen" "$xch/aurutils" "$HOME/aur"; do
  [ -d "$d" ] && caches+=("$d")
done

# 2. Pipeline di Scansione Grafica
(
    echo "10" ; echo "# [1/5] Analisi cronologia pacman.log..."
    if [ -r /var/log/pacman.log ]; then
      events=$(awk '/\[ALPM\] (installed|upgraded)/{ts=$1; gsub(/[][]/,"",ts); d=substr(ts,1,10); for(i=1;i<=NF;i++) if($i=="installed"||$i=="upgraded") print d, $(i+1)}' /var/log/pacman.log 2>/dev/null)
      foreign=$(printf '%s\n' "$events" | grep -Fwf <(pacman -Qmq 2>/dev/null) 2>/dev/null)
      window_hits=$(printf '%s\n' "$foreign" | awk -v s="$CAMPAIGN_START" 'NF && $1 >= s' | sort -u)
      if [ -n "$window_hits" ]; then
        echo -e "\n⚠️ ATTIVITÀ AUR RECENTE (Dopo il $CAMPAIGN_START):\n$window_hits" >> "$LOG_FILE"
      fi
    fi

    echo "30" ; echo "# [2/5] Scansione euristica locale (Hook e Scriptlets)..."
    hits=$(grep -rlEI "$IOC_NAMES" /var/lib/pacman/local /usr/share/libalpm/hooks /etc/pacman.d/hooks 2>/dev/null || true)
    hits+=$(grep -rlEI "$PM_ACTION" --include=install /var/lib/pacman/local 2>/dev/null || true)
    hits+=$(grep -rlEI "$PM_ACTION" --include='*.hook' /usr/share/libalpm/hooks /etc/pacman.d/hooks 2>/dev/null || true)

    if [ ${#caches[@]} -gt 0 ]; then
      for cache in "${caches[@]}"; do
        hits+=$(grep -rlEI "$IOC_NAMES" "$cache" 2>/dev/null || true)
        hits+=$(grep -rlEI "$PM_ACTION" --include='*.install' --include='*.hook' "$cache" 2>/dev/null || true)
      done
    fi
    if [ -n "$hits" ]; then
       echo -e "\n❌ IOC / PACKAGEMANAGER SOSPETTI TROVATI:\n$hits" >> "$LOG_FILE"
    fi

    echo "50" ; echo "# [3/5] Download e controllo liste nere online..."
    fetch=$(curl -fsSL --max-time 15 "$LIST_URL" 2>/dev/null || wget -qO- --timeout=15 "$LIST_URL" 2>/dev/null || true)
    if [ -n "$fetch" ]; then
      reported=$(printf '%s' "$fetch" | tr -s ' \t\r\n' '\n' | grep -E '^[a-zA-Z0-9][a-zA-Z0-9@._+-]+$' | sort -u)
      match=$(comm -12 <(pacman -Qmq 2>/dev/null | sort -u) <(printf '%s\n' "$reported"))
      if [ -n "$match" ]; then
         echo -e "\n❌ PACCHETTI AUR CORRISPONDENTI ALLA LISTA NERA:\n$match" >> "$LOG_FILE"
      fi
    fi

    echo "70" ; echo "# [4/5] Analisi persistenze Systemd e Trojan Target..."
    review=""
    for unit in /etc/systemd/system/*.service "$HOME/.config/systemd/user/"*.service; do
      [ -f "$unit" ] || continue
      if grep -q '^Restart=always' "$unit" 2>/dev/null && grep -q '^RestartSec=30' "$unit" 2>/dev/null; then
        review+="$unit -> $(grep -m1 '^ExecStart=' "$unit" 2>/dev/null)\n"
      fi
    done
    if [ -n "$review" ]; then
       echo -e "\n⚠️ SERVIZI SYSTEMD DA VERIFICARE (Euristiche):\n$review" >> "$LOG_FILE"
    fi

    if [ -e /usr/bin/monero-wallet-gui ] && ! pacman -Qo /usr/bin/monero-wallet-gui &>/dev/null; then
       echo -e "\n❌ ALERTA: /usr/bin/monero-wallet-gui presente ma NON appartiene a nessun pacchetto pacman!" >> "$LOG_FILE"
    fi

    echo "90" ; echo "# [5/5] Richiesta privilegi per scansione Rootkit eBPF..."
    echo "EBPF_CHECK" > /tmp/ag_status
) | zenity --progress --title="Arch Guard Forensic" --text="Avvio analisi euristiche..." --percentage=0 --auto-close --no-cancel || true

# 3. Controllo Rootkit eBPF (Richiede privilegi elevati via GUI)
if [ -f /tmp/ag_status ] && grep -q "EBPF_CHECK" /tmp/ag_status; then
    rm -f /tmp/ag_status
    if zenity --question --title="Scansione eBPF" --text="Vuoi eseguire la scansione dei moduli Rootkit eBPF nascosti?\nRichiede l'autenticazione root (sudo)." --width=400; then
        # Usa pkexec o sudo grafico per leggere la cartella protetta
        if command -v pkexec &>/dev/null; then
            maps=$(pkexec sh -c 'ls -d /sys/fs/bpf/hidden_* 2>/dev/null' || true)
        else
            pass=$(zenity --password --title="Richiesta Privilegi")
            maps=$(echo "$pass" | sudo -S sh -c 'ls -d /sys/fs/bpf/hidden_* 2>/dev/null' || true)
        fi
        if [ -n "$maps" ]; then
            echo -e "\n❌ CRITICO: Trovate mappe eBPF rootkit nascoste:\n$maps" >> "$LOG_FILE"
        fi
    fi
fi

# 4. Elaborazione del Verdetto Finale
if grep -qE "❌|CRITICO" "$LOG_FILE"; then
    zenity --text-info --title="⚠️ ARCH GUARD: MINACCE RILEVATE!" --text="Rilevate anomalie critiche sul sistema. Esamina attentamente i dettagli qui sotto per procedere alla rimozione manuale:" --filename="$LOG_FILE" --width=700 --height=500
else
    zenity --text-info --title="✅ Sistema Analizzato" --text="Analisi completata. Il sistema risulta strutturalmente integro. Note informative aggiuntive:" --filename="$LOG_FILE" --width=600 --height=400
fi
