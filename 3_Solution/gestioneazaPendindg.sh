#!/bin/bash

pendingFile="/var/log/monitorPending.txt"
hashFile="/var/log/hashFile.txt"
packFile="/var/log/installedPack.txt"

if [[ ! -f "$pendingFile" ]]
then
    echo "Nu există modificări în așteptare."
    exit 0
fi

while IFS= read -r line
do
    type=$(echo "$line" | cut -d' ' -f1)

    if [[ "$type" == "HASH_UPDATE" ]]
    then
        file=$(echo "$line" | cut -d' ' -f2)
        newHash=$(echo "$line" | cut -d' ' -f3)
        echo -e "\nFișierul $file a fost modificat. Vrei să actualizezi hash-ul? (da/nu):"
        read -r raspuns < /dev/tty
        if [[ "$raspuns" == "da" ]]; then
            sed -i "s|.* $file|$newHash $file|" "$hashFile"
            echo " Hash actualizat pentru $file."
        else
            echo " Hash NEactualizat pentru $file."
        fi

    elif [[ "$type" == "PACKAGE_ADD" ]]
    then
        package=$(echo "$line" | cut -d' ' -f2)
        echo -e "\nPachetul $package a fost instalat. Vrei să-l adaugi în lista de referință? (da/nu):"
        read -r raspuns < /dev/tty
        if [[ "$raspuns" == "da" ]]
        then
            echo "$package" >> "$packFile"
            echo " Pachetul $package a fost salvat."
        else
            echo " Pachetul $package NU a fost salvat."
        fi
    fi
done < "$pendingFile"


> "$pendingFile"

