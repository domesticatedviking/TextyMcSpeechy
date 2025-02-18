#!/bin/sh
# automated_espeak_rules.sh
# allows user to choose which espeak pronunciation rules will be set up automatically when the container is launched.
# this script is normally run by "prebuilt_container_run.sh"

# ALWAYS_CONFIGURE_LANGUAGES determines which ruleset(s) will be compiled when the container starts.
#    eg: "en"     - compiles english ruleset   
#    eg: "en it"  - compiles english and italian rulesets 
ALWAYS_CONFIGURE_LANGUAGES="en"  

# AUTO_APPLY_CUSTOM_ESPEAK_RULES turns rule processing on and off
#  true: automatically apply rules for configured languages when container starts 
# false: do not automatically apply these rules  
 
AUTO_APPLY_CUSTOM_ESPEAK_RULES=false

# path to main script that applies custom rules (default: "./apply_custom_rules.sh")
APPLY_CUSTOM_RULESET_SCRIPT="./apply_custom_rules.sh"

# path to logfile  (default: "tts_dojo/ESPEAK_RULES/container_apply_custom_rules.log")
# 
CUSTOM_RULESET_SCRIPT_LOGFILE="./container_apply_custom_rules.log"


auto_apply_espeak(){
# function that applies rules and displays logfile in event of error.
    # script is normally run from TextyMcSpeechy main dir by startup scripts.
    
    # to ensure logfile is built in correct location, change to ESPEAK_RULES dir
    cd tts_dojo/ESPEAK_RULES  
    
    # Conditionally apply custom espeak rules
    if [ "$AUTO_APPLY_CUSTOM_ESPEAK_RULES" = true ]; then
    # Run the script with the specified language
        echo "Applying custom eSpeak rules for language: $ALWAYS_CONFIGURE_LANGUAGES"
        $APPLY_CUSTOM_RULESET_SCRIPT "${ALWAYS_CONFIGURE_LANGUAGES}" "$CUSTOM_RULESET_SCRIPT_LOGFILE" > /dev/null 2>&1
        if [ $? -gt 0 ]; then
            echo
            echo "WARNING: Problem installing custom espeak rules." 
            sleep 2
            if [ -f $CUSTOM_RULESET_SCRIPT_LOGFILE ]; then
                echo "Here is the output of $CUSTOM_RULESET_SCRIPT_LOGFILE:"
                echo
                cat $CUSTOM_RULESET_SCRIPT_LOGFILE
            else
                echo "Logfile unavailable."
            fi
        fi
    else
        : #do nothing
    fi
    
    # return to initial directory
    cd ../..
}

auto_apply_espeak
