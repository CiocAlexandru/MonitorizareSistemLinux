#!/bin/bash

monitorFile="/var/log/monitor.csv"
hashFile="/var/log/hashFile.txt"
packFile="/var/log/installedPack.txt"
app="$1"

function initialize {
	
	echo "Initializare fisier csv de monitorizare!"
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

	echo "MonitorSystem"
}

function top {

	echo "top"
}

function monitorFiles {

	echo "Verificare diferente fisiere importante:"
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
	echo "Ports"
}


function packets {
	echo "Packets"
}

function process {
	echo "Process"
}

function cronjob {
	echo "cronjob"
}

function monitorApp {
	echo "monitorApp"
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
