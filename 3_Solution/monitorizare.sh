#!/bin/bash

monitorFile="/var/log/monitor.csv"
hashFile="/var/log/hashFile.txt"
packFile="/var/log/installedPack.txt"
configFile="/home/cioc/Practica/MonitorizareSistemLinux/3_Solution/configFile.txt"
alertFile="/var/log/alert.log"
logFile="/var/log/file.log"
monitorPendingFile="/var/log/monitorPending.txt"

cpuThres=0
memThres=0
diskThres=0
diskReadThres=0
diskWriteThres=0
netRxThres=0
netTxThres=0
app=" " 
conexiuniMax=0


function initialize {
	
	if [[ ! -f $logFile ]]
	then
		echo -e "Initializare fisier de log!" >> $logFile
		
	fi
	
	if [[ ! -f $monitorFile ]]
	then
		echo -e "Initializare fisier csv de monitorizare!"  >> $logFile
		echo "timestamp cpuPercent memUsedMB  diskUsedPercent diskReadKBPS diskWriteKBPS netRxKBPS netTxKBPS" >> $monitorFile
	fi
	
	
	if [[ ! -f $hashFile ]]
	then
		echo "Initializare fisier de monitorizare pentru fisiere importante!" >> $logFile
		for f in /etc/passwd /etc/group /etc/hosts 
		do
			sumaDenumire=`sha256sum $f`
			echo "$sumaDenumire" >> $hashFile
		done
	fi
	
	
	if [[ ! -f $packFile ]]
	then
		echo "Initializare fisier de monitorizare pachete noi!" >> $logFile
		pachete=`dpkg --get-selections | tr "\t" "," | cut -d"," -f1`
		for pachet in $pachete
		do
			echo "$pachet" >> $packFile
		done 
	fi
	
	if [[ ! -f $alertFile ]]
	then
		echo -e "Initializare fisier de alerta!" >> $logFile
		touch $alertFile
	fi
	
	if [[ ! -f $monitorPendingFile ]]
	then
		echo -e "Initializare fisier de pending!" >> $logFile
		touch $monitorPendingFile
	fi
	
}




function initializeThreshHolds {

	echo -e "\n\n\n Configurare praguri alerte:" >> $logFile

	cpuThres=`egrep "^CPU:" $configFile | cut -d":" -f2 | cut -d"%" -f1`
	memThres=`egrep "^MemoriaUtilizata:" $configFile | cut -d":" -f2 `
	diskThres=`egrep "^DiskUtilizatMB:" $configFile | cut -d":" -f2 | cut -d"%" -f1`
	diskReadThres=`egrep "^DiskReadKB:" $configFile | cut -d":" -f2 `
	diskWriteThres=`egrep "^DiskWriteKB:" $configFile | cut -d":" -f2 `
	netRxThres=`egrep "^NetRxKB:" $configFile | cut -d":" -f2 `
	netTxThres=`egrep "^NetTxKB:" $configFile | cut -d":" -f2 `
	app=`egrep "^APP:" $configFile | cut -d":" -f2 `
	conexiuniMax=`egrep "^ConexiuniMax:" $configFile | cut -d":" -f2 `
}








function monitorSystem {

    echo -e "\n\n\nMonitorizare sistem:" >> $logFile
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # CPU usage (%) folosind mpstat dacă e disponibil, altfel cu ps
    cpuPercent=$(ps -eo pcpu --no-headers | paste -sd+ - | bc)
    cpuFirstPart=`echo $cpuPercent | cut -d"." -f1`
    if [[ $cpuFirstPart -ge $cpuThres ]]
    then
    	echo  "ALERTA: Procentul de CPU depaseste valoarea $cpuThres % : $cpuPercent %" >> $alertFile
    fi
    cpuPercent="${cpuPercent}%"

    # Memorie utilizată (MB)
    memUsedMB=$(free -m | awk '/^Mem:/ {print $3}')
    
    if [[ $memUsedMB -ge $memThres ]] 
    then
    	echo  "ALERTA: Procentul de memorie Ram utilizata depaseste valoarea $memThres MB: $memUsedMB MB" >> $alertFile
    fi
    
    
    # Utilizare disk (%) pentru toate sistemele montate
    diskUsedPercent=$(df --total | awk '/total/ {print $5}')
    diskFirstPart=`echo $diskUsedPercent | cut -d"%" -f1 | cut -d "." -f1`
    
    if [[ $diskFirstPart -ge $diskThres ]]
    then
    	echo  "ALERTA: Procentul de disk utilizat depaseste valoarea $diskThres %:  $diskFirstPart %" >> $alertFile
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
    	echo  "ALERTA: Rata input de  utilizare a disk-ului depaseste valoarea $diskReadThres KB: $diskReadKBPS KB" >> $alertFile
    fi
    
    if [[ $diskWriteKBPS -ge $diskWriteThres ]] 
    then
    	echo "ALERTA: Rata output de  utilizare a disk-ului depaseste valoarea $diskWriteThres KB: $diskWriteKBPS KB" >> $alertFile
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
    	echo  "ALERTA: Viteza de download retea depaseste valoarea $netRxThres KB: $netRxKBPS KB" >> $alertFile
    fi
    
    if [[ $netTxKBPS -ge $netTxThres ]] 
    then
    	echo  "ALERTA: Viteza de upload retea depaseste valoarea $netTxThres KB: $netTxKBPS KB" >> $alertFile
    fi
    

    # Scriere în fișier CSV în formatul cerut
    echo "$timestamp $cpuPercent $memUsedMB ${diskUsedPercent} $diskReadKBPS $diskWriteKBPS $netRxKBPS $netTxKBPS" >> "$monitorFile"
}





function top {

    echo -e "\n\n\nTop 3 procese după CPU utilizat" >> "$logFile"
    ps -eo pid,%cpu,comm --sort=-%cpu | head -n 4 | tail -n 3 | tr -s " " | while read -r line 
    do
    	pid=$(echo $line | cut -d" " -f1)
    	cpu=$(echo $line | cut -d" " -f2)
    	comm=$(echo $line | cut -d" " -f3-)
    	echo "Proces: $comm (PID: $pid) → CPU: $cpu%" >> "$logFile"
    	# Verificare CPU
    	cpuFirstPart=$(echo "$cpu" | cut -d"." -f1)
    	if [[ $cpuFirstPart -ge $cpuThres ]]; then
        	echo "ALERTA CPU: Procesul '$comm' depășește $cpuThres% CPU → $cpu%" >> $alertFile
    	fi
    done

    echo "Top 3 procese după memorie utilizată (RSS MB)" >> $logFile
    ps -eo pid,rss,comm --sort=-rss | head -n 4 | tail -n 3 | while read -r pid rss comm
    do

    	memMB=$((rss / 1024))
    	echo "Process: $comm ( PID: $pid) ->RAM: ${memMB}MB" >> $logFile
    	if [[ $memMB -ge $memThres ]]
    	then
        	echo "ALERTA: Procesul '$comm' (PID $pid) folosește $memMB MB, depășind pragul de $memThres MB" >> $alertFile
    	fi
    done

	echo -e "\nTop 3 procese după Disk I/O (KB total citit + scris):" >> $logFile
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
    		echo "PID: $pid  CMD: $cmd  Disk I/O: ${total_kb}KB" >> $logFile
    
    		if [[ $total_kb -ge $((diskReadThres + diskWriteThres)) ]]; then
       			 echo "ALERTA: Procesul '$cmd' (PID $pid) a depășit pragul total $disktotal KB de I/O: ${total_kb}KB" >> $alertFile
    		fi
	done

   	echo -e "\nTop 3 procese după numărul de conexiuni de rețea active:" >> $logFile

	# Extragem PID-urile din conexiunile active
	pids=$(ss -tunp 2>/dev/null | grep -oP 'pid=\K[0-9]+' | sort | uniq -c | sort -rn)

	if [[ -z "$pids" ]]
	then
    		echo "Nicio conexiune activă detectată (ss -p nu returnează nimic)." >> $logFile
	else
    		echo "$pids" | head -n 3 | while read -r count pid
    		do
        		cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
        		echo "PID: $pid  CMD: $cmd  Conexiuni active: $count" >> $logFile

        
        		if [[ "$count" -ge $conexiuniMax ]]
        		then
           			 echo "ALERTA: Procesul '$cmd' (PID $pid) are un număr ridicat de conexiuni: $count, depasind pragul: $conexiuniMax" >> $alertFile
        		fi
    		done
	fi

}





function monitorFiles {

	echo -e "\n\n\nVerificare diferente fisiere importante:" >> $logFile
	for f in /etc/passwd /etc/group /etc/hosts 
	do
		sumaDenumireNew=`sha256sum $f`
		Denumire=`echo $sumaDenumireNew | cut -d" " -f2`
		suma=`echo $sumaDenumireNew | cut -d" " -f1`
		lineDen=`egrep "$Denumire" $hashFile`
		sumaVeche=`echo $lineDen | cut -d" " -f1`
		if [[ $suma != $sumaVeche ]]
		then
			echo "ALERTA: $f a fost modificat, $sumaVeche old , $suma new!" | tee -a "$alertFile"
			liniePending="HASH_UPDATE $f $suma"
            		if ! grep -Fxq "$liniePending" "$monitorPendingFile"
            		then
                		echo "$liniePending" >> "$monitorPendingFile"
           		 fi
		else
			echo "Nu s-a modificat nimic la fisierul $f" >> $logFile
		fi
	done
}





function ports {
	echo -e "\n\n\nPorturile de retea deschise:" >> $logFile
	ss -tuln | grep LISTEN | while read -r linie
	do
		protocol=`echo "$linie" | cut -d" " -f1`
    		port=$(echo "$linie" | tr -s " " | cut -d" " -f5 | rev | cut -d":" -f1 |rev )
                adresaPort=$(echo "$linie" | tr -s " " | cut -d" " -f5|rev | cut -d":" -f2 |rev )
                echo "Port: $port (adresa completă: $adresaPort) foloseste protocolul $protocol" >> $logFile
                echo "ALERTA: Port deschis: $port (adresa completă: $adresaPort) foloseste protocolul $protocol" >> $alertFile
	done

}





function packets {
	echo -e "\n\n\nVerificare pachete nou instalate:" >> $logFile
	pachete=`dpkg --get-selections | tr "\t" "," | cut -d"," -f1`
	for pachet in $pachete
	do
		verificarePachet=`grep -Fx "$pachet" "$packFile"`
		if [[ -z "$verificarePachet" ]]
		then
			echo "ALERTA: Pachetul $pachet este nou instalat" | tee -a "$alertFile"
			liniePending="PACKAGE_ADD $pachet"
            		if ! grep -Fxq "$liniePending" "$monitorPendingFile"
            		then
                		echo "$liniePending" >> "$monitorPendingFile"
            		fi
		fi
	done 
}




function process {
    
    echo -e "\n\n\nProcese cu drepturi de root (detalii complete):" >> $logFile

    ps -eo user,pid,%cpu,rss,comm --sort=-%cpu | grep '^root'|tr -s " " | while read -r user pid cpu rss comm
    do
    	memMB=$((rss / 1024))

    	# Afișare toate câmpurile pentru comparare
    	echo "Proces ROOT → $comm (PID: $pid)" >> $logFile
    	cpuFirstPart=`echo $cpu | cut -d"." -f1`
    	if [[ $cpuFirstPart -ge $cpuThres ]]
    	then
    		echo  -e "ALERTA: Procentul de CPU depaseste valoarea $cpuThres % : $cpu %" >> $alertFile
    	fi
    	if [[ $memMB -ge $memThres ]] 
    	then
    		echo -e "ALERTA: Procentul de memorie Ram utilizata depaseste valoarea $memThres MB: $memMB MB" >> $alertFile
    	fi
    done
}





function cronjob {
    echo -e "\n\n\nToate Cronjob-urile din sistem:" >> $logFile

    echo  -e "\n Crontab pentru toți utilizatorii din /var/spool/cron/crontabs:\n" >> $logFile
    for file in /var/spool/cron/crontabs/*
    do
        user=$(basename "$file")
        echo -e "\nCronjob-uri pentru utilizator: $user\n" >> $logFile
        sudo cat "$file" 2>/dev/null >> $logFile
    done

    echo -e "\n /etc/crontab (crontab global):"  >> $logFile
    cat /etc/crontab 2>/dev/null >> $logFile

    echo -e "\n Fișiere cron din /etc/cron.d/:" >> $logFile
    for f in /etc/cron.d/*
    do
        echo -e "\n--- $f ---" >> $logFile
        cat "$f" 2>/dev/null >> $logFile
    done

    echo -e "\n Scripturi automate (cron.hourly, cron.daily, etc.):"  >> $logFile
    for d in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly
    do
        echo -e "\nConținut $d" >> $logFile
        ls -l "$d" 2>/dev/null >> $logFile
    done

    echo -e "\nSfârșit listă cronjob-uri\n"  >> $logFile
}





function monitorApp {
	echo -e "\n\n\nMonitorizare aplicatie: $app" >> $logFile
	timestamp=`date +"%Y-%m-%d %H:%M:%S"`

        # Verifică dacă aplicația rulează
        pid=`pgrep -f "$app" | head -n1`

        if [[ -z "$pid" ]]
        then
                echo "$timestamp - Aplicația "$app" NU rulează." >> $logFile
        return
        fi
        
        # CPU și memorie utilizată de proces
        cpu=$(ps -p "$pid" -o %cpu= | tr -d ' ')
        mem=$(ps -p "$pid" -o rss= | tr -d ' ')
        memMB=$((mem / 1024))
        
        echo "$timestamp - Aplicația '$app' rulează." >> $logFile
        echo "$timestamp - $app (PID: $pid) -> CPU: ${cpu}%, Memorie: ${memMB}MB" >> $logFile

        
        
        cpuFirstPart=`echo $cpu | cut -d"." -f1`
    	if [[ $cpuFirstPart -ge $cpuThres ]]
    	then
    		echo  "ALERTA: Procentul de CPU al aplicatie $app depaseste valoarea $cpuThres % : $cpu %" >> $alertFile
    	fi
        
        
	
	if [[ $memMB -ge $memThres ]] 
    	then
    		echo  "ALERTA: Procentul de memorie Ram utilizata de aplicatia $app depaseste valoarea $memThres MB: $memMB MB" >> $alertFile
    	fi
	
        
        
        # Proces părinte (PPID)
	ppid=$(ps -p "$pid" -o ppid= | tr -d ' ')
	parent_process=$(ps -p "$ppid" -o comm= 2>/dev/null)
	echo "→ Proces părinte (PPID: $ppid) → $parent_process" >> $logFile
	
	
	# Procese copil (dacă există)
	child_pids=$(pgrep -P "$pid")

	

	if [[ -n "$child_pids" ]]
	then
    		echo " Procese copil:" >> $logFile
    		for child in $child_pids
    		do
        		child_name=$(ps -p "$child" -o comm= 2>/dev/null)
        		echo "   - PID: $child, Proces: $child_name" >> $logFile
    		done
    	
	else
    		echo " Nu există procese copil active!" >> $logFile
	fi
}








function main {
	
	initialize
	initializeThreshHolds
		
	while true
	do
		timestamp=`date +"%Y-%m-%d %H:%M:%S"`
		echo -e "\n\n\nAlerte la $timestamp:" >> $alertFile
		echo -e "\n\n\nEvenimente la $timestamp:" >> $logFile
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
