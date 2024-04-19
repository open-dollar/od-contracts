#!/bin/bash
source .env

set -e

###############
## FUNCTIONS ##
###############


function passProp(){
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}

  CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
    RPC_ENDPOINT=""
      if [[ $NETWORK = "arb-sepolia" || $NETWORK = "sepolia" ]]; then echo "incorrect network" exit 2
          elif [[ $NETWORK = "anvil" ]]; then RPC_ENDPOINT=$ANVIL_RPC
          elif [[ $NETWORK = "arb-mainnet" || $NETWORK = "mainnet" ]]; then echo "incorrect network" exit 2
          else
            echo "Unrecognized target environment"
            exit 1    
      fi
        echo "Simulating..."

      FOUNDRY_PROFILE=governance forge script script/testScripts/gov/helpers/PassAnvilProp.s.sol:PassAnvilProp -s $CALLDATA --rpc-url $RPC_ENDPOINT

      read -p "Please verify the data and confirm that you want to pass this proposal (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Passing proposal on Anvil..."
        FOUNDRY_PROFILE=governance forge script script/testScripts/gov/helpers/PassAnvilProp.s.sol:PassAnvilProp -s $CALLDATA --rpc-url $RPC_ENDPOINT --broadcast
   
fi
}

function display_help() {
            echo "Usage:"
            echo " yarn propose:submit [target environment] [proposalType] "
            echo "    where target environment (required): anvil / arb-sepolia  / arb-mainnet"
            echo "    the type of proposal to be generated"
            echo "    your inputs in the correct order.  use --help for more info"
            echo ""
            echo "Example:"
            echo "yarn propose:submit arb-sepolia /gov-output/arb-sepolia/67531219-add-collateral-proposal.json"
        exit 0
}

function makeCall() {
    node ./tasks/anvilRPCCalls.js $1 $2
    exit 0
}

while :
do
    case "$1" in
      "")
        display_help
          ;;
      -h | --help)
          display_help
          ;;
      -d | --display)
          display="$2"
           shift 2
           ;;

      -a | --add-options)
          # do something here call function
          # and write it in your help function display_help()
           shift 2
           ;;
        -r | --rpc-call)
          makeCall $2 $3
          ;;
      --) # End of all options
          shift
          break
          ;;
      -*)
          echo "Error: Unknown option: $1" >&2
          ## or call function display_help
          exit 1 
          ;;
      *)  # No more options
          break
          ;;
    esac
done


###################### 
# Check if parameter #
# is set then execute #
######################

if [[ $1 != "" && $2 == "" ]]; then passProp $1
        elif [[ $1 == "rpc-call" ]]; then makeCall $2 $3
    else 
    display_help

fi

exit 0;