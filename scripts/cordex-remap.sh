#!/bin/bash

GRID=$1
FOLDER=$2
MAX_FILES=${3:-0}
NSD=${4:-6}

# Check for cdo and ncrepack-cordex commands
if ! command -v cdo &> /dev/null; then
    echo "Error: cdo command not found. Please install CDO (Climate Data Operators) to proceed."
    exit 1
fi
if ! command -v ncks &> /dev/null; then
    echo "Error: ncks command not found. Please install NCO to proceed."
    exit 1
fi
if ! command -v ncrepack-cordex &> /dev/null; then
    echo "Error: ncrepack-cordex command not found. Please install ncrepack-cordex to proceed."
    exit 1
fi

# Check if the grid and folder arguments are provided
if [ -z "$GRID" ] || [ -z "$FOLDER" ]; then
    echo "Usage: $0 <grid> <folder> [MAX_FILES] [NSD]"
    exit 1
fi
if ! [[ "$NSD" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: NSD must be a positive integer."
    exit 1
fi
if ! [[ "$MAX_FILES" =~ ^[0-9]+$ ]]; then
    echo "Error: MAX_FILES must be a non-negative integer."
    exit 1
fi

# Check if the specified grid file exists
if [ ! -f "${GRID}.grid" ]; then
    echo "Error: Grid file '${GRID}.grid' does not exist."
    exit 1
fi

# Check if the specified folder exists
if [ ! -d "$FOLDER" ]; then
    echo "Error: Folder '$FOLDER' does not exist."
    exit 1
fi

# Create a temporary directory for intermediate files
TEMP_DIR=$(mktemp -d)

# Loop through all .nc files in the specified folder
FILE_COUNT=0
for FILE in "$FOLDER"/*.nc; do
    # Check if the file exists (in case there are no .nc files)
    if [ ! -e "$FILE" ]; then
        echo "No .nc files found in the folder '$FOLDER'."
        break
    fi
    # Process each .nc file
    BASENAME=$(basename "$FILE")
    echo "Processing $BASENAME..."
    cdo remapbil,${GRID}.grid "$FILE" "$TEMP_DIR/$BASENAME"
    FILE_COUNT=$((FILE_COUNT + 1))
    if [ "$MAX_FILES" -gt 0 ] && [ "$FILE_COUNT" -ge "$MAX_FILES" ]; then
        break
    fi
done

DATE_RANGE=$(ls -1 "$TEMP_DIR" | awk -F'[_.-]' 'NR == 1 { first = $(NF-2) } { last = $(NF-1) } END { if (NR) print first "-" last }')
if [ -z "$DATE_RANGE" ]; then
    echo "Error: Could not extract dates from remapped filenames."
    exit 1
fi

OLD_GRID=$(echo "$BASENAME" | cut -d_ -f2)
NAME_NO_DATES="${BASENAME%_*}"
OUTPUT_FILENAME="${NAME_NO_DATES/$OLD_GRID/$GRID}_${DATE_RANGE}.nc"

cdo mergetime "$TEMP_DIR"/*.nc $OUTPUT_FILENAME
# Lossy compression: keep NSD significant digits
ncks -O --ppc default=$NSD $OUTPUT_FILENAME $OUTPUT_FILENAME
ncrepack-cordex -o $OUTPUT_FILENAME
rm -rf "$TEMP_DIR"
