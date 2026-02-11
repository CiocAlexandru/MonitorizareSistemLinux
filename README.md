🖥️ Monitorizare Sistem Linux
A Bash-based Linux system monitoring solution that runs as a persistent systemd service. The project collects system metrics, manages pending alerts, and logs activity automatically in the background.

📋 Descriere
Monitorizare Sistem Linux este un proiect de practică ce implementează un sistem de monitorizare a resurselor unui sistem Linux (CPU, memorie, disk, procese, pachete instalate). Scriptul principal rulează continuu ca serviciu systemd, colectând date și salvând rapoarte în fișiere CSV și log-uri text.

🏗️ Structura Proiectului
MonitorizareSistemLinux/
├── 3_Solution/
│   ├── monitorizare.sh          # Scriptul principal de monitorizare
│   ├── gestioneazaPending.sh    # Gestionare alerte/evenimente pending
│   ├── instalareServiciu.sh     # Instalare automată ca serviciu systemd
│   ├── configFile.txt           # Fișier de configurare parametri
│   ├── monitor.csv              # Date colectate (output)
│   ├── monitorPending.txt       # Evenimente în așteptare
│   ├── hashFile.txt             # Verificare integritate fișiere
│   └── installedPack.txt        # Lista pachete instalate

✨ Funcționalități

📊 Colectare metrici sistem – CPU, memorie RAM, spațiu disk, procese active
🔄 Rulare continuă – serviciu systemd cu restart automat
📁 Export CSV – datele sunt salvate în monitor.csv pentru analiză ulterioară
⏳ Gestionare pending – alerte și evenimente procesate prin gestioneazaPending.sh
🔐 Verificare integritate – hash-uri pentru validarea fișierelor de configurare
📦 Inventar pachete – înregistrarea pachetelor instalate în sistem
⚙️ Instalare automată – script dedicat pentru înregistrarea ca serviciu systemd


🛠️ Tehnologii Utilizate
ComponentăTehnologieScriptingBashInit systemsystemdDate outputCSV, TXTIntegritateSHA hashOSLinux (Ubuntu/Debian)

🚀 Instalare și Utilizare
Cerințe

Linux cu systemd (Ubuntu, Debian, Fedora etc.)
Bash 4.0+
Drepturi sudo

Pas 1 – Clonare repository
bashgit clone https://github.com/CiocAlexandru/MonitorizareSistemLinux.git
cd MonitorizareSistemLinux/3_Solution
Pas 2 – Configurare
Editează configFile.txt pentru a seta parametrii de monitorizare (intervale, praguri etc.):
bashnano configFile.txt
Pas 3 – Instalare ca serviciu systemd
bashchmod +x instalareServiciu.sh
./instalareServiciu.sh
Scriptul va:

Verifica existența monitorizare.sh
Crea fișierul de serviciu în /etc/systemd/system/monitorizare.service
Activa și porni serviciul automat

Pas 4 – Verificare status
bashsudo systemctl status monitorizare

⚙️ Configurare Serviciu systemd
Fișierul de serviciu generat automat de instalareServiciu.sh:
ini[Unit]
Description=Monitorizare sistem - serviciu custom
After=network.target

[Service]
ExecStart=/path/to/monitorizare.sh
Restart=always
User=root
StandardOutput=file:/var/log/monitorizare.log
StandardError=file:/var/log/monitorizare.err

[Install]
WantedBy=multi-user.target

📊 Fișiere de Output
FișierConținutmonitor.csvMetrici sistem colectate periodicmonitorPending.txtAlerte/evenimente în așteptareinstalledPack.txtLista pachetelor instalatehashFile.txtHash-uri pentru verificarea integrității/var/log/monitorizare.logLog-uri de execuție ale serviciului/var/log/monitorizare.errErori înregistrate de serviciu

🔧 Comenzi Utile
bash# Pornire manuală serviciu
sudo systemctl start monitorizare

# Oprire serviciu
sudo systemctl stop monitorizare

# Vizualizare log-uri în timp real
sudo journalctl -u monitorizare -f

# Vizualizare log fișier
tail -f /var/log/monitorizare.log

# Dezactivare serviciu
sudo systemctl disable monitorizare

👤 Autor
Alexandru Cioc – Academia Tehnică Militară „Ferdinand I", București
📧 alexandru-marian.cioc@stud.mta.ro
🔗 github.com/CiocAlexandru

📄 Licență
Proiect dezvoltat în scop educațional în cadrul stagiului de practică.
