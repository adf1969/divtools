#!/bin/bash
# Script to fix QBO files - removes long memo/name fields and replaces with shortened codes
# Last Updated: 12/20/2025 10:00:00 AM CDT

# Parse command line flags
TEST_MODE=0
DEBUG_MODE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -test|--test) TEST_MODE=1; shift ;;
        -debug|--debug) DEBUG_MODE=1; shift ;;
        *) break ;;
    esac
done

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/util/logging.sh" 2>/dev/null || {
    # Fallback logging if not found
    log() {
        local level="$1"; shift
        echo "[$level] $*" >&2
    }
}

[ "$DEBUG_MODE" -eq 1 ] && log "DEBUG" "Script started with TEST_MODE=$TEST_MODE, DEBUG_MODE=$DEBUG_MODE"

process_name() {
    local memo="$1"
    local trimmed_memo=""
    local replacement=""

    # Remove <CR> and <LF> characters from memo
    memo=$(echo "$memo" | tr -d '\r\n')

    # Determine the replacement
    case "$memo" in
        # Specific case for exact output: This exits EARLY and does not further processing.
        *"PAYMENT"* | *"SECURE ONLINE TXFR TO LOAN 128627265"*)
            # Validate PAYMENT followed by any characters and LOAN 128627265
            if echo "$memo" | grep -E -q "PAYMENT.*LOAN[ ]*128627265"; then
                trimmed_memo="SECU ONLI TXFR TO LOC7265"
                echo "$trimmed_memo"
                return # Exit early to skip further processing
            elif echo "$memo" | grep -q "SECURE ONLINE TXFR TO LOAN 128627265"; then
                trimmed_memo="SECU ONLI TXFR TO LOC7265"
                echo "$trimmed_memo"
                return # Exit early to skip further processing
            fi
            ;;

        # Specific case for exact output: This exits EARLY and does not further processing.
        *"SECURE ONLINE TXFR FROM BUSINESS CHECKING 31083108"*)
            # Validate PAYMENT followed by any characters and LOAN 128627265
            if echo "$memo" | grep -E -q "TXFR FROM.*31083108"; then
                trimmed_memo="SECU ONLI TXFR FROM CVG3108"
                echo "$trimmed_memo"
                return # Exit early to skip further processing
            fi
            ;;


        *"PAYMENT TO COMMERCIAL RE LOAN 118595256"*)
            trimmed_memo="PMT TO LOAN RE5256"            
            echo "$trimmed_memo"
            return # Exit early to skip further processing
            ;;
        *"PAYMENT TO COMMERCIAL RE LOAN 118537217"*)
            trimmed_memo="PMT TO LOAN RE7217"            
            echo "$trimmed_memo"
            return # Exit early to skip further processing
            ;;
        *"PAYMENT TO COMMERCIAL RE LOAN 118472712"*)
            trimmed_memo="PMT TO LOAN RE2712"            
            echo "$trimmed_memo"
            return # Exit early to skip further processing
            ;;
        *"WELLS FARGO * LOAN * 000000014772277"*)
            trimmed_memo="PMT TO WF LOAN LEASE"
            echo "$trimmed_memo"
            return # Exit early to skip further processing
            ;;

        # Put most strict matches at the top
        *"31218365"*) replacement="OP8365";;        # AVAK-OP2 Acct
        *"30047088"*) replacement="CH7088";;        # AVAK-Hotel Acct
        *"31182454"*) replacement="CG2454";;        # AVAK-Restaurant Acct
        *"30997266"*) replacement="RT7266";;        # AVAK-Rental Acct
        *"30047112"*) replacement="GS7112";;        # AVAK-Gift Shop Acct
        *"31182637"*) replacement="AR2637";;        # AVAK-Restructure Acct

        # Less strict at the bottom
        *"GLENNALLEN HARDW"*) replacement="GLENHW";;# 614.10 Maint & Rep ; HOTEL
        *"AMAZON"*) replacement="AMAZON";;         # 790.00 Misc Exp
        *"HUB OF ALASKA"*) replacement="HUBOFAK";; # 645.00 Fuel ; HOTEL
        *"WM SUPERCENTER"*) replacement="WMSUPER";;# 610.00 Supplies ; OFFICE
        *"GLENNALLEN FUEL"*) replacement="GLNFUEL";;# 616.00:645.00 Fuel ; OFFICE
        *"COPPER VALLEY TE"*) replacement="CVTEL";;# 616.60 Telephone (CVTC) ; HOTEL
        *"COPPER VALLEY EL"*) replacement="CVELEC";;# 616.20 Electric ; HOTEL
        *"BRENNER COMPANY"*) replacement="BRENNER";;# 706.03 Accounting ; OFFICE
        *"187 GLENN HWY"*) replacement="187GH";;   #
        *"DTVDIRECTV"*) replacement="DIRECTV";;     # 616.70 Cable TV ; RENTALS
        *"HOME DEPOT"*) replacement="HOMEDEP";;     # 614.10 Maint & Rep ; ???
        *"TRANS ALASKA MECHAN"*) replacement="TRANAKM";;# 614.10 Maint & Rep
        *"KALADI BROTHERS"*) replacement="KALADIB";;# 615.20 Food ; HOTEL
        *"E INTL AIRPORT"*) replacement="EIAIRPT";; # 
        *"IN GLENNALLEN"*) replacement="INGLENN";;  #
        *"FRED MEYE"*) replacement="FREDMEY";;      # 645.00 Fuel ; OFFICE
        *"CHEVRON"*) replacement="CHEVRON";;        # 645.00 Fuel ; OFFICE
        *"Coadvantage"*) replacement="COADVAN";;    # 6560 Payroll ; ???
        *"SHELL SERVICE"*) replacement="SHELLSV";;  # 645.00 Fuel ; OFFICE
        *"CTS SYSTEMS"*) replacement="CTSSYS";;     # 708.00 Advertising ; HOTEL
        *"VISTAPRINT"*) replacement="VISTAPR";;     # 610.10 Office Supplies ; HOTEL
        *"ADOBE ACROPRO"*) replacement="ACROPRO";;  # 790.00:709.00 Computer Pgms ; OFFICE
        *"USPS PO"*) replacement="USPSPO";;         # 620.00 Postage ; OFFICE
        *"COOLWORKSCOM"*) replacement="COOLWRK";;   # 728.00 Hotel Emp Advertising ; HOTEL
        *"THREE BEARS"*) replacement="3BEARS";;     # 3 Bears
        *"JOY MEDIA"*) replacement="JOYMEDIA";;     # Joy Media
        *"AMERICAS BEST VA"*) replacement="AMBESTVA";;     # Americans Best VA
        *) replacement="";;
    esac

    # Determine max length based on whether a replacement was found
    local max_length=32
    if [ ! -z "$replacement" ]; then
        max_length=24
    fi

    # Construct the trimmed name
    local memo_words=($memo)
    for word in "${memo_words[@]}"; do
        local trimmed_word=""
        if [[ $word =~ ^[0-9]+$ ]]; then
            trimmed_word=$(echo "$word" | cut -c1-4)
        else
            trimmed_word=$(echo "$word" | cut -c1-4)
        fi

        if [ $(( ${#trimmed_memo} + ${#trimmed_word} + 1 )) -le $max_length ]; then
            trimmed_memo="${trimmed_memo}${trimmed_word} "
        else
            break
        fi
    done

    # Trim trailing spaces
    trimmed_memo=$(echo "$trimmed_memo" | sed 's/ *$//')

    # Add the replacement if applicable
    if [ ! -z "$replacement" ]; then
        trimmed_memo="${trimmed_memo} ${replacement}"
    fi

    echo "$trimmed_memo"
}

process_file() {
    local input_file="$1"
    local output_file=""
    local temp_output=""
    
    if [ -z "$2" ]; then
        output_file="${input_file%.*}-FIXED.qbo"
    else
        output_file="$2"
    fi

    [ "$DEBUG_MODE" -eq 1 ] && log "DEBUG" "Processing file: $input_file -> $output_file (TEST_MODE=$TEST_MODE)"

    # For test mode, use temp file; for normal mode, use output file
    if [ "$TEST_MODE" -eq 1 ]; then
        temp_output=$(mktemp)
    else
        temp_output="$output_file"
        [ -f "$output_file" ] && rm "$output_file"
    fi

    # Count total lines in the input file for progress tracking
    local total_lines=$(wc -l < "$input_file")
    local current_line=0

    in_stmttrn=0
    name_line=""
    memo_line=""
    modified_name=""
    indentation=""

    while IFS= read -r line; do
        # Increment line counter
        ((current_line++))
        
        # Display progress only in non-debug, non-test mode
        if [ "$DEBUG_MODE" -eq 0 ] && [ "$TEST_MODE" -eq 0 ]; then
            local percent_complete=$(echo "scale=2; ($current_line * 100) / $total_lines" | bc)
            echo -ne "Progress: Line $current_line/$total_lines ($percent_complete% Complete)\r" >&2
        fi

        if echo "$line" | grep -q "<STMTTRN>"; then
            in_stmttrn=1
        fi

        if [ $in_stmttrn -eq 1 ]; then
            if echo "$line" | grep -q "<NAME>"; then
                name_line="$line"
                indentation=$(echo "$line" | grep -o '^[[:space:]]*')
                name_content="${line#*<NAME>}"
                if [ ${#name_content} -gt 32 ]; then
                    modified_name=1
                else
                    modified_name=0
                fi
            elif echo "$line" | grep -q "<MEMO>" && [ $modified_name -eq 1 ]; then
                memo_line="${line#*<MEMO>}"
                trimmed_name_line="${indentation}<NAME>$(process_name "$memo_line")"
                echo "$trimmed_name_line" >> "$temp_output"
            elif echo "$line" | grep -q "<MEMO>"; then
                # If <NAME> was not modified, print it before <MEMO>
                if [ $modified_name -eq 0 ]; then
                    echo "$name_line" >> "$temp_output"
                fi
            fi

            if echo "$line" | grep -q "</STMTTRN>"; then
                in_stmttrn=0
            fi

            if [ "$line" != "$name_line" ]; then
                echo "$line" >> "$temp_output"
            fi
        else
            echo "$line" >> "$temp_output"
        fi
    done < "$input_file"

    # Print newline after progress to avoid overwriting
    if [ "$DEBUG_MODE" -eq 0 ] && [ "$TEST_MODE" -eq 0 ]; then
        echo -e "\n" >&2
    fi

    if [ "$TEST_MODE" -eq 1 ]; then
        # In test mode, output to stdout
        log "INFO" "===== TEST MODE: Output for $input_file ====="
        cat "$temp_output"
        log "INFO" "===== END TEST OUTPUT ====="
        rm "$temp_output"
    else
        log "INFO" "Finished processing: $input_file -> $output_file"
        [ "$DEBUG_MODE" -eq 1 ] && log "DEBUG" "Output file created with ${current_line} lines processed"
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage:"
    echo "  ${0##*/} [options] file1.qbo [file2.qbo ...]"
    echo "  ${0##*/} [options] *.qbo"
    echo ""
    echo "Options:"
    echo "  -test, --test     Run in test mode (output to stdout, no files created)"
    echo "  -debug, --debug   Enable debug logging"
    echo ""
    echo "Examples:"
    echo "  ${0##*/} myfile.qbo              # Creates myfile-FIXED.qbo"
    echo "  ${0##*/} -test myfile.qbo        # Shows output to stdout without creating file"
    echo "  ${0##*/} -debug *.qbo            # Process all .qbo files with debug output"
    exit 1
fi

[ "$DEBUG_MODE" -eq 1 ] && log "DEBUG" "Processing $# file(s): $@"

for input_file in "$@"; do
    # Skip flags that might be in the argument list
    if [[ "$input_file" == -* ]]; then
        continue
    fi
    
    if [[ "$input_file" == *-FIXED.qbo ]]; then
        log "INFO" "Skipping already processed file: $input_file"
        continue
    fi
    
    if [ ! -f "$input_file" ]; then
        log "ERROR" "File not found: $input_file"
        continue
    fi
    
    process_file "$input_file"
done

[ "$DEBUG_MODE" -eq 1 ] && log "DEBUG" "Script completed"
