#! /bin/bash

# GIF FUNCTION
    function gif(){
## Include the pkgfile
    source ${BASH_SOURCE%/*}/pkgfile
## Auxiliary Functions
### format the geometry
    function GIF_cropped_geometry(){
        IFS='x' read -ra dimensions_geometry <<< "$1"
        IFS='+' read -ra coordinates_geometry <<< "${dimensions_geometry[1]}"
        x="${coordinates_geometry[1]}"
        y="${coordinates_geometry[2]}"
        IFS='x' read -ra dimensions_cropped_area <<< "$2"
        width=${dimensions_cropped_area[0]}
        height=${dimensions_cropped_area[1]}
        cropped_geometry="${width}x${height}+${x}+${y}"
    }
### select the window area and take the first screenshot
    function GIF_init(){
        if [[ -d "/tmp/gif" ]]; then
            rm -r /tmp/gif
            mkdir /tmp/gif
            mkdir /tmp/gif/0
        else
            mkdir /tmp/gif
            mkdir /tmp/gif/0
        fi
        part=0
        first_image=$(import -verbose /tmp/gif/0/0.png)
        read -r -a imagemagick_output <<< "$first_image"
        geometry=${imagemagick_output[3]}
        cropped_area=${imagemagick_output[2]}
        GIF_cropped_geometry $geometry $cropped_area
        convert /tmp/gif/0/0.png -quality $1 -crop $cropped_geometry /tmp/gif/0/0.jpg
    }
### use the selected area in the formatted geometry to take enter in a loop of screenshots 
### and put it on the background.
    function GIF_screenshots(){
        sleep_time=$(bc -l <<< "scale=4; 1/$2")
        screnshot_number=0
        while true; do  
            screnshot_number=$(($screnshot_number + 1))
            import -window root -crop $3 /tmp/gif/$1/${screnshot_number}.png
            convert /tmp/gif/0/${screnshot_number}.png -quality $4 /tmp/gif/0/${screnshot_number}.jpg
            sleep $sleep_time
        done &
        disown
    }
### stop the loop of screenshots: find the PPID of the loop and kill it
    function GIF_stop(){
        sleep_time_stop=0.01
        time=.00
        while (( $(echo "$time <= 3.00" | bc -l) )); do
            ppid_lines=$(ps -ef | grep "import -window" | awk '{ print $3 }')
            number_of_lines=$(echo "$ppid_lines" | wc -l)
            if [[ $number_of_lines -le 1 ]]; then
                ppid=""
                sleep $sleep_time
                time=$(echo "$time + $sleep_time" | bc -l)
                continue
            else
                ppid=$(echo "$ppid_lines" | head -n 1)
                kill $ppid > /dev/null 2>&1
                break
            fi
        done       
    }
### start a new loop of screenshots
    function GIF_continue(){
        part=$(($part +1))
        mkdir /tmp/gif/$part
        first_image=$(import -verbose /tmp/gif/$part/0.png)
        read -r -a imagemagick_output <<< "$first_image"
        geometry=${imagemagick_output[3]}
        convert /tmp/gif/$part/0.png -quality $1 /tmp/gif/$part/0.jpg
        GIF_screenshots $part $2 $3 $1
    }
### collect each directory of screenshots and create a .gif from it
### join all .gifs in a single one
    function GIF_finish(){
        GIF_stop
        echo "Creating the .gif..."
        declare -a list
        for (( i=0; i<=$part; i++ )); do
            convert -delay 20 -loop 0 $(ls -v1 /tmp/gif/$i/*.jpg) /tmp/gif/$i.gif
            list[$i]=/tmp/gif/${i}.gif
        done 
        eval "convert ${list[*]} -delay 20 -loop 0 $1"
        while [[ -f "a.out" ]]; do
            GIF_STOP
            rm a.out
            continue
        done
        echo "Done."
    }
### make use of gifsicle to optimize the the .gif 
    function GIF_optimize(){
        cropped_geometry_gifsicle="${x},${y}+${width}x${height}"
        gifsicle --crop $cropped_geometry_gifsicle -O3 -k $2 $1 -o $1  
    }
## GIF Function Properly
### without any input, execute GIF_init and GIF_screenshots with default fps and quality
    if [[ -z "$1" ]]; then
        fps=10
        quality=70
        name=""
        GIF_init $quality
        GIF_screenshots $part $fps $geometry $quality
### execute GIF_init and GIF_screenshots with given fps and quality inputs
    elif ([[ "$1" == "-fps" ]] || [[ "$1" == "--frames-per-second" ]]) && 
       ([[ "$3" == "-q" ]] || [[ "$3" == "--quality" ]]); then
        fps=$2
        quality=$4
        name="$5"
        GIF_init $quality
        GIF_screenshots $part $fps $geometry $quality
### execute GIF_init and GIF_screenshots with given fps and quality inputs
    elif ([[ "$3" == "-fps" ]] || [[ "$3" == "--frames-per-second" ]]) && 
         ([[ "$1" == "-q" ]] || [[ "$1" == "--quality" ]]); then
        fps=$4
        quality=$2
        name="$5"
        GIF_init $quality
        GIF_screenshots $part $fps $geometry $quality
### execute GIF_init and GIF_screenshots with given fps and default quality inputs
    elif ([[ "$1" == "-fps" ]] || [[ "$1" == "--frames-per-second" ]]); then
        fps=$2
        quality=70
        name="$3"
        GIF_init $quality
        GIF_screenshots $part $fps $geometry $quality 
### execute GIF_init and GIF_screenshots with given quality and default fps inputs
    elif ([[ "$1" == "-q" ]] || [[ "$1" == "--quality" ]]); then
        fps=10
        quality=$2
        name="$3"
        GIF_init $quality
        GIF_screenshots $part $fps $geometry $quality
### execute GIF_stop
    elif [[ "$1" == "-s" ]] || [[ "$1" == "--stop" ]]; then
        GIF_stop
        if [[ -z "$ppid" ]]; then
            echo "error: There is none running process."
        fi
### execute GIF_continue
    elif [[ "$1" == "-c" ]] || [[ "$1" == "--continue" ]]; then
        if [[ -n "$fps" ]] && [[ -n "$quality" ]]; then
            GIF_continue $quality $fps $geometry
        else
            echo "error: There is none stopped process."
        fi
### execute GIF_finish with given name or with default name
    elif [[ "$1" == "-f" ]] || [[ "$1" == "--finish" ]]; then
        if [[ -n "$fps" ]] && [[ -n "$quality" ]]; then
            if [[ -n "$name" ]]; then
                NAME=${name%.*}
                GIF_finish $NAME.gif
            else
                GIF_finish output.gif
            fi
        else
            echo "error: There is none running process to finish."
        fi
### execute GIF_optimize recursively or in a given .gif file
    elif [[ "$1" == "-o" ]] || [[ "$1" == "--optimize" ]]; then
        if [[ -z "$2" ]]; then
            mapfile -d '' gif_files < <(find . -maxdepth 1 -type f -iname "*.gif" -print0)
            for f in ${gif_files[@]}; do
                echo "Optimizing \"$2\"..."
                colors=16
                GIF_optimize $f $colors
                echo "Done."
            done
        elif [[ "${2##*.}" == "gif" ]]; then
            echo "Optimizing \"$2\"..."
            colors=16
            GIF_optimize $2 $colors
            echo "Done."
        else
            echo "error: \"$2\" is not a .gif file."
        fi
### execute imgur.sh recursively or in a given .gif file
    elif [[ "$1" == "-u" ]] || [[ "$1" == "--upload" ]]; then
        if [[ -z "$2" ]]; then
            mapfile -d '' gif_files < <(find . -maxdepth 1 -type f -iname "*.gif" -print0)
            for f in ${gif_files[@]}; do
                echo "Uploading \"$f\"..."
                imgur $f
                echo "Done."
            done
        elif [[ "${2##*.}" == "gif" ]]; then
            echo "Uploading \"$2\"..."
            imgur $2
            echo "Done."
        else
            echo "error: \"$2\" is not a .gif file."
        fi       
## print help
        elif ([[ "$1" == "-h" ]] || 
              [[ "$1" == "--help" ]]) &&
              [[ -z "$2" ]]; then
            cat $PKG_install_dir/config/help.txt
## execute the uninstall script
        elif [[ "$1" == "--uninstall" ]]; then
            sh  $PKG_install_dir/install/uninstall
## default error
        else 
            echo "Option not defined for the \"gif()\" function."
        fi
    }
   
