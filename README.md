# arch-infected-pkg-check
A lightweight, real-time security scanner for Arch Linux and derivatives (EndeavourOS, Manjaro, CachyOS) that detects known compromised packages.

# 🛡️ Arch Linux Ecosystem - Infected Package Scanner

Un piccolo e potente script in Bash progettato per verificare istantaneamente se il tuo sistema è infetto da pacchetti compromessi. Lo script scarica in tempo reale la lista ufficiale dei pacchetti maligni tracciata dal team di Arch Linux e la confronta con i pacchetti installati localmente.

## 🚀 Funzionalità
- **Multi-distro:** Compatibile al 100% con **Arch Linux**, **EndeavourOS**, **Manjaro** e **CachyOS**.
- **Scansione Totale:** Verifica sia i pacchetti dei repository ufficiali sia quelli installati tramite AUR (tramite `yay`, `paru`, `pamac`, ecc.).
- **Aggiornato in Tempo Reale:** Sincronizza i dati direttamente dall'HedgeDoc ufficiale di Arch Linux.
- **Notifiche Desktop:** Invia un avviso visivo di sistema (`notify-send`) con priorità critica se viene rilevata una minaccia.
- **Sicuro e Trasparente:** Scritto in Bash puro, senza dipendenze esterne pesanti (richiede solo `curl`, `sed`, `grep` e `pacman`).

## 📋 Prerequisiti
Lo script richiede che il pacchetto `libnotify` sia installato se desideri ricevere le notifiche grafiche sul desktop (già presente di default su quasi tutti gli ambienti grafici).

```bash
# Se non presente, puoi installarlo con:
sudo pacman -S libnotify
```

## 🛠️ Installazione e Utilizzo

### 1. Clona il repository o scarica lo script
```bash
git clone https://github.com
cd NOME_REPOSTORY
```

### 2. Rendi lo script eseguibile
```bash
chmod +x check-infected.sh
```

### 3. Avvia la scansione
```bash
./check-infected.sh
```

## ⚙️ Come funziona?
1. **Verifica l'OS:** Controlla la presenza di `pacman` e legge `/etc/os-release` per identificare la distribuzione corrente.
2. **Download sicuro:** Scarica la lista dei pacchetti compromessi isolando la pipeline in modalità sicura (`set -euo pipefail`).
3. **Parsing dei dati:** Pulisce i tag HTML e isola i nomi dei pacchetti tramite espressioni regolari (Regex).
4. **Intersezione binaria:** Utilizza il comando nativo `comm` per confrontare i dati alla massima velocità, senza sovraccaricare la CPU.

## 🤝 Contributi
Le segnalazioni di bug e le pull request sono benvenute! Se noti modifiche nel formato della pagina ufficiale di Arch Linux che rompono il parsing del codice, apri subito una *Issue*.

## 📄 Licenza
Questo progetto è rilasciato sotto licenza MIT. Vedi il file `LICENSE` per maggiori dettagli.
