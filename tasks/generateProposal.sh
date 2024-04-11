#!/bin/bash
source .env

set -e
###############
## FUNCTIONS ##
###############

function parsePath(){
  NETWORK="$1"
      RPC_ENDPOINT=""
    if [[ $NETWORK = "arb-sepolia" || $NETWORK = "sepolia" ]]; then
             RPC_ENDPOINT=$ARB_SEPOLIA_RPC
          elif [[ "$NETWORK" = "anvil" ]]; then

               RPC_ENDPOINT=$ANVIL_RPC
          elif [[ "$NETWORK" = "arb-mainnet" || "$NETWORK" = "mainnet" ]]; then
               RPC_ENDPOINT=$ARB_MAINNET_RPC
          else
            echo "Unrecognized target environment"
            exit 1    
      fi
    COMMAND_PATH=$(node tasks/parseProposalPath.js $2)
    CALLDATA=$(cast calldata "run(string)" $2)

      FOUNDRY_PROFILE=governance forge script $COMMAND_PATH -s $CALLDATA --rpc-url $RPC_ENDPOINT

}

function display_help() {

 
            echo "Usage:"
            echo " yarn script:generate [target environment] [proposalPath]"
            echo "    where target environment (required): anvil / arb-sepolia / arb-mainnet"
            echo "    the path to the proposal JSON file"
            echo "    your inputs in the correct order.  use -help for more info"
            echo ""
            echo "Example:"
            echo "yarn script:generate arb-sepolia /gov-input/new-addCollateral-prop.json"
          exit 0
}

while :
do
    case "$1" in
      "")
          display_help
        exit 1
          ;;
      -h | --help)
          display_help
          exit 1
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

if [[ $1 != "" && $2 != "" ]]
  then
  parsePath $1 $2
  else
   display_help
fi

exit 0

