#!/bin/bash

# Create a temporary working directory and assign it to a variable
WORKDIR=$(mktemp -d)
echo "Temporary working directory: $WORKDIR"

# YYYYMMDD_HHMMSS
readonly CURRENT_DATETIME=$(date +"%Y%m%d_%H%M%S")
echo "Current date and time: $CURRENT_DATETIME"
# path to file uploader binary
FILE_UPLOADER_BINARY="/Users/Shared/FileUploader"


#put the stuff you want to upload into the temporary working directory

#run sysdiagnose
/usr/bin/sysdiagnose -u -f "$WORKDIR" -A "sysdiagnose-$CURRENT_DATETIME"

# other stuff you want to upload here
# stuff
# stuff
# stuff
# stuff
# stuff
# stuff
# stuff
# stuff

# Zip everything in the temporary working directory
zip -r "$WORKDIR/upload-$CURRENT_DATETIME.zip" "$WORKDIR"

# Upload the zip file to the server
"$FILE_UPLOADER_BINARY" "$WORKDIR/upload-$CURRENT_DATETIME.zip"


#clean up the temporary working directory
rm -rf "$WORKDIR"
