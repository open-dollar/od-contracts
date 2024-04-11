#!/bin/bash
source .env

set -e

###############
## FUNCTIONS ##
###############

function propose(){
  NETWORK=$1
    CALLDATA=$(cast calldata "run(string)" $2)
    RPC_ENDPOINT=""
      if [[ $NETWORK = "arb-sepolia" || $NETWORK = "sepolia" ]]; then RPC_ENDPOINT=$ARB_SEPOLIA_RPC
          elif [[ NETWORK = "anvil" ]]; then RPC_ENDPOINT=$ANVIL_RPC
          elif [[ $NETWORK = "arb-mainnet" || $NETWORK = "mainnet" ]]; then RPC_ENDPOINT=$ARB_MAINNET_RPC
          else
            echo "Unrecognized target environment"
            exit 1    
      fi
    
      FOUNDRY_PROFILE=governance forge script script/testScripts/gov/Proposer.s.sol:Proposer -s $CALLDATA --rpc-url $RPC_ENDPOINT

      read -p "Please verify the data and confirm the submission of this proposal (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Executing..."
        FOUNDRY_PROFILE=governance forge script script/testScripts/gov/Proposer.s.sol:Proposer -s $CALLDATA --rpc-url $RPC_ENDPOINT --broadcast
   
fi
}

while :
do
    case "$1" in
      "")
            echo "Usage:"
            echo " yarn script:propose [target environment] [proposalType] "
            echo "    where target environment (required): anvil / arb-sepolia  / arb-mainnet"
            echo "    the type of proposal to be generated"
            echo "    your inputs in the correct order.  use --help for more info"
            echo ""
            echo "Example:"
            echo "yarn script:propose arb-sepolia /gov-output/arb-sepolia/67531219-add-collateral-proposal.json"
        exit 1
          ;;
      -h | --help)
          display_help
          exit 1
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

if [[ $1 != "" ]]
  then propose $1 $2

fi

