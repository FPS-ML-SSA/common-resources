#!/bin/bash

GRID=$1
FOLDER=$2

# Check for cdo and ncrepack-cordex commands
if ! command -v cdo &> /dev/null; then
    echo "Error: cdo command not found. Please install CDO (Climate Data Operators) to proceed."
    exit 1
fi
if ! command -v ncrepack-cordex &> /dev/null; then
    echo "Error: ncrepack-cordex command not found. Please install ncrepack-cordex to proceed."
    exit 1
fi

# Check if the grid and folder arguments are provided
if [ -z "$GRID" ] || [ -z "$FOLDER" ]; then
    echo "Usage: $0 <grid> <folder>"
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
done

FIRST_FILE=$(ls "$TEMP_DIR"/*.nc | head -n 1)
LAST_FILE=$(ls "$TEMP_DIR"/*.nc | tail -n 1)
FIRST_DATE=$(echo "$FIRST_FILE" | grep -oP '\d{12}-\d{12}' | head -n 1 | cut -c1-8)
LAST_DATE=$(echo "$LAST_FILE" | grep -oP '\d{12}-\d{12}' | head -n 1 | cut -c10-17)
OUTPUT_FILENAME="${BASENAME%_*}_${FIRST_DATE}-${LAST_DATE}.nc"

cdo mergetime "$TEMP_DIR"/*.nc $OUTPUT_FILENAME
ncrepack-cordex -o $OUTPUT_FILENAME
rm -rf "$TEMP_DIR"
