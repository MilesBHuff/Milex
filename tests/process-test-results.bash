#!/usr/bin/env bash
#NOTE: I am aware that this can be done pretty much entirely in `awk`, but I do not know `awk`.
export LC_COLLATE=en_US.utf8
[[ "$1" == '-r' ]] && RAW=1 || RAW=0

## Helper functions
function field {
    echo "$1" | cut -d ' ' -f$2
}
function expr {
    echo "$1" | bc -l
}
function round {
    echo "$1" | xargs printf "%.${2:-2}f"
    #echo "$1" | xargs printf "%.2f"
}
function iecify {
    numfmt --to=iec --suffix=iB <<< "$1"
}

## Convert the disparate files into a serialized format
RESULTS_FILE=$(mktemp)
declare -i FILECOUNT=0; FILECOUNT_FILE=$(mktemp)
for FILE in ./zfs-compression-tests/*; do
    cat "$FILE" | perl -pe 's/([\|%]|[\t]+|M\/s)//g' | perl -pe 's/ +$//' | perl -pe 's/\ [^\ ]+://g'
    echo $((++FILECOUNT)) > "$FILECOUNT_FILE"
done | sort -V > "$RESULTS_FILE"
FILECOUNT=$(cat "$FILECOUNT_FILE"); rm "$FILECOUNT_FILE"

## Break the output up into one file per algorithm, making sure to notate the sourcedir's size
ALGO_DIR=$(mktemp -d)
declare -i SIZE_ORIGINAL=0
while read LINE; do
    ALGO=$(field "$LINE" 1)
    if [[ "$ALGO" == 'source' ]]; then
        SIZE_ORIGINAL=$(field "$LINE" 2)
        continue
    fi
    echo "${LINE#* }" >> "$ALGO_DIR/$ALGO"
done < "$RESULTS_FILE"
rm -f "$RESULTS_FILE"

## Average the bytes and time, then calculate new speeds and ratios; then write them all to a new file; then print the file.
AVGS_FILE=$(mktemp)
if [[ $RAW -eq 1 ]]; then
    echo "algorithm,bytes,seconds,rate,ratio"
    echo "source,$SIZE_ORIGINAL,,,1"
else
    echo -e "source\t| Size: $(iecify $SIZE_ORIGINAL)\t|            \t|               \t| Ratio: 100.00%"
fi
for FILE in "$ALGO_DIR"/*; do

    SIZE_SUBTOTAL=0; SIZE_SUBTOTAL_FILE=$(mktemp)
    TIME_SUBTOTAL=0; TIME_SUBTOTAL_FILE=$(mktemp)

    while read LINE; do
        SIZE=$(field "$LINE" 1)
        TIME=$(field "$LINE" 2)

        SIZE_SUBTOTAL=$(expr "$SIZE_SUBTOTAL + $SIZE")
        TIME_SUBTOTAL=$(expr "$TIME_SUBTOTAL + $TIME")

        echo "$SIZE_SUBTOTAL" > "$SIZE_SUBTOTAL_FILE"
        echo "$TIME_SUBTOTAL" > "$TIME_SUBTOTAL_FILE"
    done < "$FILE"

    SIZE_SUBTOTAL=$(cat "$SIZE_SUBTOTAL_FILE"); rm "$SIZE_SUBTOTAL_FILE"
    TIME_SUBTOTAL=$(cat "$TIME_SUBTOTAL_FILE"); rm "$TIME_SUBTOTAL_FILE"

    SIZE_AVG=$(expr "$SIZE_SUBTOTAL / $FILECOUNT")
    TIME_AVG=$(expr "$TIME_SUBTOTAL / $FILECOUNT")
    SPEED_AVG=$(expr "$SIZE_ORIGINAL / $TIME_AVG")
    RATIO_AVG=$(expr "$SIZE_AVG / $SIZE_ORIGINAL")

    if [[ $RAW -eq 1 ]]; then
        SIZE_DISPLAY=$(round "$SIZE_AVG" 0)
        TIME_DISPLAY=$(round "$TIME_AVG" 7)
        SPEED_DISPLAY="$SPEED_AVG"
        RATIO_DISPLAY="0$RATIO_AVG"
    else
        SIZE_DISPLAY=$(iecify $(round "$SIZE_AVG"))
        TIME_DISPLAY=$(echo $(round "$TIME_AVG")s)
        SPEED_DISPLAY=$(echo $(iecify $(round "$SPEED_AVG"))/s)
        RATIO_DISPLAY=$(echo $(round $(expr "$RATIO_AVG * 100"))%)
    fi

    ALGO=$(basename "$FILE")
    if [[ $RAW -eq 1 ]]; then
        echo "$ALGO,$SIZE_DISPLAY,$TIME_DISPLAY,$SPEED_DISPLAY,$RATIO_DISPLAY" >> "$AVGS_FILE"
    else
        echo -e "$ALGO\t| Size: $SIZE_DISPLAY\t| Time: $TIME_DISPLAY\t| Rate: $SPEED_DISPLAY\t| Ratio:  $RATIO_DISPLAY" >> "$AVGS_FILE"
    fi
done

rm -rf "$ALGO_DIR"
cat "$AVGS_FILE" | sort -V
rm -f "$AVGS_FILE"
exit 0
