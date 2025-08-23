#!/data/data/com.termux/files/usr/bin/bash

#folder="/sdcard/Download/NOKAAAAT"
folder=$(dirname $0)


if [ "$whoami" = "root" ] ;then
    echo "exit from root user and try agin"
    exit
fi

if [ ! -d $folder ] ;then
    echo "Error: $folder Not exist !!!"
    echo "exiting ..."
    exit
fi
echo '##########' > $folder/termux-packages.txt

repos=($(pkg list-installed 2>/dev/null | grep '\-repo/' | cut -d'/' -f 1))

if [[ ! -z ${repos[0]} ]]; then
	echo "Please install the following repositories before installing the packages:"
	echo "Please install the following repositories before installing the packages:" >> $folder/termux-packages.txt
	echo  "${repos[@]}"
	echo  "${repos[@]}" >> $folder/termux-packages.txt
fi


echo "Outputing installed termux package list to"
echo "$folder/termux-packages.txt"
echo >> $folder/termux-packages.txt
            echo "---------------------" >> $folder/termux-packages.txt
            echo "install following termux package with \"pkg install\"" >> $folder/termux-packages.txt
            echo >> $folder/termux-packages.txt
pkg list-installed 2>/dev/null | grep -oE '^[^/]*' | tail -n +2 | tr '\n' ' ' >> $folder/termux-packages.txt

if [ -f /data/data/com.termux/files/usr/bin/pip ];then
    cat /data/data/com.termux/files/usr/bin/pip 2>/dev/null | grep 'from pip' &>/dev/null
    if [ $? -eq 0 ]; then
        echo "Python pip seems to be installed"
        str=$(pip list 2>/dev/null | tail -n +3 2>/dev/null | grep -v 'pip' 2>/dev/null | grep -o -e '^[^ ]*' 2>/dev/null)
        if [ ! -z "$str" ];then
            echo "outputing installed python pip package list to"
            echo "$folder/termux-packages.txt"
            echo $'\n\n---------------------' >> $folder/termux-packages.txt
            echo "install following python package with \"pip install\"" >> $folder/termux-packages.txt
            echo >> $folder/termux-packages.txt
            echo $str >> $folder/termux-packages.txt
        else
            echo "No installed pip package found !!!"
        fi
    fi     
fi
