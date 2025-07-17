#!/bin/bash

monitorFile="/var/log/monitor.csv"
hashFile="/var/log/hashFile.txt"
packFile="/var/log/installedPack.txt"
configFile="/home/cioc/Practica/MonitorizareSistemLinux/3_Solution/configFile.txt"

cpuThres=0
memThres=0
diskThres=0
diskReadThres=0
diskWriteThres=0
netRxThres=0
netTxThres=0
app=" " 





function initializeThreshHolds {

	echo -e "\n\n\n Configurare praguri alerte:"

	cpuThres=`egrep "^CPU:" $configFile | cut -d":" -f2 | cut -d"%" -f1`
	memThres=`egrep "^MemoriaUtilizata:" $configFile | cut -d":" -f2 `
	diskThres=`egrep "^DiskUtilizatMB:" $configFile | cut -d":" -f2 | cut -d"%" -f1`
	diskReadThres=`egrep "^DiskReadKB:" $configFile | cut -d":" -f2 `
	diskWriteThres=`egrep "^DiskWriteKB:" $configFile | cut -d":" -f2 `
	netRxThres=`egrep "^NetRxKB:" $configFile | cut -d":" -f2 `
	netTxThres=`egrep "^NetTxKB:" $configFile | cut -d":" -f2 `
	app=`egrep "^APP:" $configFile | cut -d":" -f2 `

}




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
    cpuFirstPart=`echo $cpuPercent | cut -d"." -f1`
    if [[ $cpuFirstPart -ge $cpuThres ]]
    then
    	echo -e "\nALERTA: Procentul de CPU depaseste valoarea $cpuThres % : $cpuPercent %"
    fi
    cpuPercent="${cpuPercent}%"

    # Memorie utilizată (MB)
    memUsedMB=$(free -m | awk '/^Mem:/ {print $3}')
    
    if [[ $memUsedMB -ge $memThres ]] 
    then
    	echo -e "\nALERTA: Procentul de memorie Ram utilizata depaseste valoarea $memThres MB: $memUsedMB MB"
    fi
    
    
    # Utilizare disk (%) pentru toate sistemele montate
    diskUsedPercent=$(df --total | awk '/total/ {print $5}')
    diskFirstPart=`echo $diskUsedPercent | cut -d"%" -f1 | cut -d "." -f1`
    
    if [[ $diskFirstPart -ge $diskThres ]]
    then
    	echo -e "\nALERTA: Procentul de disk utilizat depaseste valoarea $diskThres %:  $diskFirstPart %"
    fi
    
    
    # Disk I/O - pentru sda (adaptează dacă ai alt device)
    disk1=$(awk '$3=="sda" {print $6, $10}' /proc/diskstats)
    sleep 1
    disk2=$(awk '$3=="sda" {print $6, $10}' /proc/diskstats)

    read1=$(echo $disk1 | cut -d' ' -f1)
    write1=$(echo $disk1 | cut -d' ' -f2)
    read2=$(echo $disk2 | cut -d' ' -f1)
    write2=$(echo $disk2 | cut -d' ' -f2)

    sectorSize=512
    diskReadKBPS=$(( (read2 - read1) * sectorSize / 1024 ))
    diskWriteKBPS=$(( (write2 - write1) * sectorSize / 1024 ))
    
    if [[ $diskReadKBPS -ge $diskReadThres ]] 
    then
    	echo -e "\nALERTA: Rata input de  utilizare a disk-ului depaseste valoarea $diskReadThres KB: $diskReadKBPS KB"
    fi
    
    if [[ $diskWriteKBPS -ge $diskWriteThres ]] 
    then
    	echo -e "\nALERTA: Rata output de  utilizare a disk-ului depaseste valoarea $diskWriteThres KB: $diskWriteKBPS KB"
    fi
    
    
    # Interfață rețea activă
    iface=$(ip route | awk '/default/ {print $5}' | head -n1)
    rx1=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/net/dev)
    tx1=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/net/dev)
    sleep 1
    rx2=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/net/dev)
    tx2=$(awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/net/dev)

    netRxKBPS=$(( (rx2 - rx1) / 1024 ))
    netTxKBPS=$(( (tx2 - tx1) / 1024 ))
    
    if [[ $netRxKBPS -ge $netRxThres ]] 
    then
    	echo -e "\nALERTA: Viteza de download retea depaseste valoarea $netRxThres KB: $netRxKBPS KB"
    fi
    
    if [[ $netTxKBPS -ge $netTxThres ]] 
    then
    	echo -e "\nALERTA: Viteza de upload retea depaseste valoarea $netTxThres KB: $netTxKBPS KB"
    fi
    

    # Scriere în fișier CSV în formatul cerut
    echo "$timestamp $cpuPercent $memUsedMB ${diskUsedPercent} $diskReadKBPS $diskWriteKBPS $netRxKBPS $netTxKBPS" >> "$monitorFile"
}





function top {

    echo -e "\n\n\nTop 3 procese după CPU utilizat"
    ps -eo pid,comm,%cpu, --sort=-%cpu | head -n 4 | tail -n 3 | while read -r pid comm cpu
    do
    	echo "Proces: $comm (PID: $pid) → CPU: $cpu%"
    	# Verificare CPU
    	cpuFirstPart=$(echo "$cpu" | cut -d"." -f1)
    	if [[ $cpuFirstPart -ge $cpuThres ]]; then
        	echo " ALERTA CPU: Procesul '$comm' depășește $cpuThres% CPU → $cpu%"
    	fi
    done

    echo "Top 3 procese după memorie utilizată (RSS MB)"
    ps -eo pid,rss,comm --sort=-rss | head -n 4 | tail -n 3 | while read -r pid rss comm
    do

    	memMB=$((rss / 1024))
    	echo "Process: $comm ( PID: $pid) ->RAM: ${memMB}MB"
    	if [[ $memMB -ge $memThres ]]
    	then
        	echo "ALERTA: Procesul '$comm' (PID $pid) folosește $memMB MB, depășind pragul de $memThres MB"
    	fi
    done

	echo -e "\nTop 3 procese după Disk I/O (KB total citit + scris):"
	# Inițializăm un array temporar
	declare -a ioData=()

	# Iterăm prin toate PIDs
	for pid in $(ls /proc | grep '^[0-9]\+$')
	do
    		if [[ -r /proc/$pid/io && -r /proc/$pid/cmdline ]]; then
        	read_bytes=$(sudo egrep "^read_bytes:" /proc/$pid/io|cut -d" " -f2)
        	write_bytes=$(sudo egrep "^write_bytes:" /proc/$pid/io|cut -d" " -f2)
        	cmd=$(tr '\0' ' ' < /proc/$pid/cmdline | cut -d' ' -f1)

        	read_bytes=${read_bytes:-0}
        	write_bytes=${write_bytes:-0}
        	total_kb=$(( (read_bytes + write_bytes) / 1024 ))

        	ioData+=("$total_kb:$pid:$cmd")
    	fi
	done

	disktotal=$((diskReadThres + diskWriteThres))

	# Sortăm array-ul și afișăm top 3
	for entry in $(printf "%s\n" "${ioData[@]}" | sort -rn | head -n 3)
	do
    		total_kb=$(echo "$entry" | cut -d':' -f1)
    		pid=$(echo "$entry" | cut -d':' -f2)
    		cmd=$(echo "$entry" | cut -d':' -f3)
    		echo "PID: $pid  CMD: $cmd  Disk I/O: ${total_kb}KB"
    
    		if [[ $total_kb -ge $((diskReadThres + diskWriteThres)) ]]; then
       			 echo "ALERTĂ: Procesul '$cmd' (PID $pid) a depășit pragul total $disktotal KB de I/O: ${total_kb}KB"
    		fi
	done

    echo -e "\nTop 3 procese după utilizare rețea (KB/s):"

declare -a netData=()

for pid in $(ls /proc | grep '^[0-9]\+$'); do
    if [[ -r /proc/$pid/net/dev && -r /proc/$pid/cmdline ]]
    then
        iface=$(ip route | awk '/default/ {print $5}' | head -n1)

        rx1=$(sudo awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/$pid/net/dev 2>/dev/null)
        tx1=$(sudo awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/$pid/net/dev 2>/dev/null)

        sleep 1

        rx2=$(sudo awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $2}' /proc/$pid/net/dev 2>/dev/null)
        tx2=$(sudo awk -v iface="$iface" '$0 ~ iface {gsub(/:/,"",$1); print $10}' /proc/$pid/net/dev 2>/dev/null)

        if [[ -n "$rx1" && -n "$rx2" && -n "$tx1" && -n "$tx2" ]]; then
            deltaRx=$(( (rx2 - rx1) / 1024 ))
            deltaTx=$(( (tx2 - tx1) / 1024 ))
            total=$((deltaRx + deltaTx))

            cmd=$(tr '\0' ' ' < /proc/$pid/cmdline | cut -d' ' -f1)
            netData+=("$total:$deltaRx:$deltaTx:$pid:$cmd")
        fi
    fi
done

totalNetThres=$((netRxThres + netTxThres))

for entry in $(printf "%s\n" "${netData[@]}" | sort -rn | head -n 3); do
    totalKB=$(echo "$entry" | cut -d':' -f1)
    rxKB=$(echo "$entry" | cut -d':' -f2)
    txKB=$(echo "$entry" | cut -d':' -f3)
    pid=$(echo "$entry" | cut -d':' -f4)
    cmd=$(echo "$entry" | cut -d':' -f5)

    echo "PID: $pid  CMD: $cmd  RX: ${rxKB}KB/s  TX: ${txKB}KB/s  TOTAL: ${totalKB}KB/s"

    if [[ $totalKB -ge $totalNetThres ]]; then
        echo "ALERTĂ: Procesul '$cmd' (PID $pid) a depășit pragul de rețea total $totalNetThres KB/s → ${totalKB}KB/s"
    fi
done

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
	ss -tuln | grep LISTEN | while read -r linie
	do
		protocol=`echo "$linie" | cut -d" " -f1`
    		port=$(echo "$linie" | tr -s " " | cut -d" " -f5 | rev | cut -d":" -f1 |rev )
                adresaPort=$(echo "$linie" | tr -s " " | cut -d" " -f5|rev | cut -d":" -f2 |rev )
                echo " ALERTA: Port deschis: $port (adresa completă: $adresaPort) foloseste protocolul $protocol"
	done

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
    
    echo -e "\n\n\nProcese cu drepturi de root (detalii complete):"

    ps -eo user,pid,%cpu,rss,comm --sort=-%cpu | grep '^root'|tr -s " " | while read -r user pid cpu rss comm
    do
    	memMB=$((rss / 1024))

    	# Afișare toate câmpurile pentru comparare
    	echo "Proces ROOT → $comm (PID: $pid)"
    	cpuFirstPart=`echo $cpu | cut -d"." -f1`
    	if [[ $cpuFirstPart -ge $cpuThres ]]
    	then
    		echo  -e "ALERTA: Procentul de CPU depaseste valoarea $cpuThres % : $cpu %\n\n"
    	fi
    	if [[ $memMB -ge $memThres ]] 
    	then
    		echo -e "ALERTA: Procentul de memorie Ram utilizata depaseste valoarea $memThres MB: $memMB MB\n\n"
    	fi
    done
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
                echo "$timestamp - Aplicația "$app" NU rulează."
        return
        fi
        
        echo "$timestamp - Aplicația '$app' rulează."
        echo "$timestamp - $app (PID: $pid) -> CPU: ${cpu}%, Memorie: ${memMB}MB"

        # CPU și memorie utilizată de proces
        cpu=$(ps -p "$pid" -o %cpu= | tr -d ' ')
        
        cpuFirstPart=`echo $cpu | cut -d"." -f1`
    	if [[ $cpuFirstPart -ge $cpuThres ]]
    	then
    		echo -e "\nALERTA: Procentul de CPU al aplicatie $app depaseste valoarea $cpuThres % : $cpu %"
    	fi
        mem=$(ps -p "$pid" -o rss= | tr -d ' ')
        memMB=$((mem / 1024))
	
	if [[ $memMB -ge $memThres ]] 
    	then
    		echo -e "\nALERTA: Procentul de memorie Ram utilizata de aplicatia $app depaseste valoarea $memThres MB: $memMB MB"
    	fi
	
        
        
        # Proces părinte (PPID)
	ppid=$(ps -p "$pid" -o ppid= | tr -d ' ')
	parent_process=$(ps -p "$ppid" -o comm= 2>/dev/null)
	echo "→ Proces părinte (PPID: $ppid) → $parent_process"
	
	
	# Procese copil (dacă există)
	child_pids=$(pgrep -P "$pid")

	

	if [[ -n "$child_pids" ]]
	then
    		echo " Procese copil:"
    		for child in $child_pids
    		do
        		child_name=$(ps -p "$child" -o comm= 2>/dev/null)
        		echo "   - PID: $child, Proces: $child_name"
    		done
    	
	else
    		echo " Nu există procese copil active!"
	fi
}





function main {
	
	initializeThreshHolds
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
		monitorApp
		
		sleep 60
	done 
}

main
