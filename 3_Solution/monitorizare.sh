#!/bin/bash

monitorFile="/var/log/monitor.csv"
hashFile="/var/log/hashFile.txt"
packFile="/var/log/installedPack.txt"
app="$1"




function initialize {
	
	echo -e "\n\n\nInitializare fisier csv de monitorizare!"
	if [[ ! -f $monitorFile ]]
	then
		echo "timestamp cpuPercent memUsedMB  diskUsedPercent diskReadKBPS diskWriteKBPS netRxKBPS netTxKBPS" >> $monitorFile
	fi
	
	echo "Initializare fisier de monitorizare pentru fisiere importante!"
	if [[ ! -f $hashFile ]]
	then
		for f in /etc/passwd /etc/group /etc/hosts 
		do
			sumaDenumire=`sha256sum $f`
			echo "$sumaDenumire" >> $hashFile
		done
	fi
	
	echo "Initializare fisier de monitorizare pachete noi!"
	if [[ ! -f $packFile ]]
	then
		pachete=`dpkg --get-selections | tr "\t" "," | cut -d"," -f1`
		for pachet in $pachete
		do
			echo "$pachet" >> $packFile
		done 
	fi
	
}





function monitorSystem {

    echo -e "\n\n\nMonitorizare sistem:"
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # CPU usage (%) folosind mpstat dacă e disponibil, altfel cu ps
    cpuPercent=$(ps -eo pcpu --no-headers | paste -sd+ - | bc)
    cpuPercent="${cpuPercent}%"

    # Memorie utilizată (MB)
    memUsedMB=$(free -m | awk '/^Mem:/ {print $3}')

    # Utilizare disk (%) pentru toate sistemele montate
    diskUsedPercent=$(df --total | awk '/total/ {print $5}')
    
    # Disk I/O - pentru sda (adaptează dacă ai alt device)
    disk1=$(awk '$3=="sda" {print $6, $10}' /proc/diskstats)
    sleep 5
    disk2=$(awk '$3=="sda" {print $6, $10}' /proc/diskstats)

    read1=$(echo $disk1 | cut -d' ' -f1)
    write1=$(echo $disk1 | cut -d' ' -f2)
    read2=$(echo $disk2 | cut -d' ' -f1)
    write2=$(echo $disk2 | cut -d' ' -f2)

    sectorSize=512
    diskReadKBPS=$(( (read2 - read1) * sectorSize / 1024 ))
    diskWriteKBPS=$(( (write2 - write1) * sectorSize / 1024 ))

    # Interfață rețea activă
    iface=$(ip route | awk '/default/ {print $5}' | head -n1)
    rx1=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/net/dev)
    tx1=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/net/dev)
    sleep 5
    rx2=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/net/dev)
    tx2=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/net/dev)

    netRxKBPS=$(( (rx2 - rx1) / 1024 ))
    netTxKBPS=$(( (tx2 - tx1) / 1024 ))

    # Scriere în fișier CSV în formatul cerut
    echo "$timestamp $cpuPercent $memUsedMB ${diskUsedPercent} $diskReadKBPS $diskWriteKBPS $netRxKBPS $netTxKBPS" >> "$monitorFile"
}





function top {

    echo -e "\n\n\nTop 3 procese după CPU utilizat"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -n 4

    echo "Top 3 procese după memorie utilizată (RSS MB)"
    ps -eo pid,comm,rss --sort=-rss | head -n 4 | awk 'NR==1 {print $0} NR>1 {printf "%s %s %.1fMB\n", $1, $2, $3/1024}'

    echo -"Disk I/O rate (KB/s)"
    diskDevice=$(lsblk -ndo NAME | grep '^sd[a-z]$' | head -n1)
    [ -z "$diskDevice" ] && diskDevice="sda"

    read1=$(awk -v dev="$diskDevice" '$3==dev {print $6}' /proc/diskstats)
    write1=$(awk -v dev="$diskDevice" '$3==dev {print $10}' /proc/diskstats)
    sleep 5
    read2=$(awk -v dev="$diskDevice" '$3==dev {print $6}' /proc/diskstats)
    write2=$(awk -v dev="$diskDevice" '$3==dev {print $10}' /proc/diskstats)

    sectorSize=512
    readKBps=$(( (read2 - read1) * sectorSize / 1024 ))
    writeKBps=$(( (write2 - write1) * sectorSize / 1024 ))

    echo "Read: ${readKBps}KB/s  Write: ${writeKBps}KB/s"

    echo -e "\nUtilizare rețea (KB/s)]"
    iface=$(ip route | awk '/default/ {print $5}' | head -n1)
    rx1=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/net/dev)
    tx1=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/net/dev)
    sleep 1
    rx2=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/net/dev)
    tx2=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/net/dev)

    rxKBps=$(( (rx2 - rx1) / 1024 ))
    txKBps=$(( (tx2 - tx1) / 1024 ))

    echo "RX: ${rxKBps}KB/s  TX: ${txKBps}KB/s"
}





function monitorFiles {

	echo -e "\n\n\nVerificare diferente fisiere importante:"
	for f in /etc/passwd /etc/group /etc/hosts 
	do
		sumaDenumireNew=`sha256sum $f`
		Denumire=`echo $sumaDenumireNew | cut -d" " -f2`
		suma=`echo $sumaDenumireNew | cut -d" " -f1`
		lineDen=`egrep "$Denumire" $hashFile`
		sumaVeche=`echo $lineDen | cut -d" " -f1`
		if [[ $suma != $sumaVeche ]]
		then
			echo "ALERTA: $f a fost modificat, $sumaVeche old , $suma new!"
		else
			echo "Nu s-a modificat nimic la fisierul $f"
		fi
	done
}





function ports {
	echo -e "\n\n\nPorturile de retea deschise:"
	ss -tuln | egrep "LISTEN"
}





function packets {
	echo -e "\n\n\nVerificare pachete nou instalate:"
	pachete=`dpkg --get-selections | tr "\t" "," | cut -d"," -f1`
	for pachet in $pachete
	do
		verificarePachet=`grep -Fx "$pachet" "$packFile"`
		if [[ -z "$verificarePachet" ]]
		then
			echo "ALERTA: Pachetul $pachet este nou instalat"
		fi
	done 
}




function process {
	echo -e "\n\n\nProcese cu drepturi de root:"
   	ps -eo user,pid,ppid,cmd --sort=user | egrep '^root' 
}





function cronjob {
    echo -e "\n\n\nToate Cronjob-urile din sistem:"

    echo  -e "\n[1] Crontab pentru toți utilizatorii din /var/spool/cron/crontabs:\n"
    for file in /var/spool/cron/crontabs/*
    do
        user=$(basename "$file")
        echo -e "\nCronjob-uri pentru utilizator: $user\n"
        sudo cat "$file" 2>/dev/null
    done

    echo -e "\n[2] /etc/crontab (crontab global):" 
    cat /etc/crontab 2>/dev/null

    echo -e "\n[3] Fișiere cron din /etc/cron.d/:"
    for f in /etc/cron.d/*
    do
        echo -e "\n--- $f ---" 
        cat "$f" 2>/dev/null
    done

    echo -e "\n[4] Scripturi automate (cron.hourly, cron.daily, etc.):" 
    for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly
    do
        echo -e "\nConținut $d"
        ls -l "$d" 2>/dev/null
    done

    echo -e "\nSfârșit listă cronjob-uri\n" 
}





function monitorApp {
	echo -e "\n\n\nMonitorizare aplicatie: $app"
	timestamp=`date +"%Y-%m-%d %H:%M:%S"`

        # Verifică dacă aplicația rulează
        pid=`pgrep -f "$app" | head -n1`

        if [[ -z "$pid" ]]
        then
                echo "$timestamp - Aplicația '$app' NU rulează."
        return
        fi

        # CPU și memorie utilizată de proces
        cpu=$(ps -p "$pid" -o %cpu= | tr -d ' ')
        mem=$(ps -p "$pid" -o rss= | tr -d ' ')
        memMB=$((mem / 1024))

        # Output pe ecran
        echo "$timestamp - Aplicația '$app' rulează."
        echo "$timestamp - $app (PID: $pid) -> CPU: ${cpu}%, Memorie: ${memMB}MB"
}





function main {
	
	initialize
	
	while true
	do
		monitorSystem
		top
		monitorFiles
		ports
		packets
		process
		cronjob
		monitorApp app
		
		sleep 60
	done 
}

main
