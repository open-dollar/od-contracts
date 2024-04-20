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
          elif [[ $NETWORK = "anvil" ]]; then RPC_ENDPOINT=$ANVIL_RPC PRIVATE_KEY=$ANVIL_ONE
          elif [[ $NETWORK = "arb-mainnet" || $NETWORK = "mainnet" ]]; then echo "incorrect network" exit 2
          else
            echo "Unrecognized target environment"
            exit 1    
      fi
        echo "Simulating... "

      FOUNDRY_PROFILE=governance 
      simulatePassProp $CALLDATA  $ANVIL_RPC  $PRIVATE_KEY

      read -p "Please verify the data and confirm that you want to pass this proposal (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Passing proposal on Anvil..."
        FOUNDRY_PROFILE=governance 
        broadcastPassProp $CALLDATA $ANVIL_RPC $PRIVATE_KEY
   
fi
}

function queue(){
      declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
    NETWORK=${OUTPUT[0]}
    CAST_PATH=${OUTPUT[1]}
    PRIVATE_KEY=$ANVIL_ONE
    echo "$PRIVATE_KEY"
    CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
     forge script script/testScripts/gov/QueueProposal.s.sol:QueueProposal -s $CALLDATA --rpc-url $ANVIL_RPC  --private-key $PRIVATE_KEY

     read -p "Please verify the data and confirm that you want to pass this proposal (y/n):" CONFIRMATION
     if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Passing proposal on Anvil..."
         forge script script/testScripts/gov/QueueProposal.s.sol:QueueProposal -s $CALLDATA --rpc-url $ANVIL_RPC --private-key $PRIVATE_KEY --broadcast
    fi
     exit 0
}

function delegate(){
    declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
    NETWORK=${OUTPUT[0]}
    CAST_PATH=${OUTPUT[1]}
    PRIVATE_KEY=$ANVIL_ONE
    echo "$PRIVATE_KEY"
    CALLDATA=$(cast calldata "delegateTokens(string)" $CAST_PATH)
        simulatePassProp $CALLDATA  $ANVIL_RPC  $PRIVATE_KEY

     read -p "Please verify the data and confirm that you want to pass this proposal (y/n):" CONFIRMATION
     if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Passing proposal on Anvil..."
         broadcastPassProp $CALLDATA $ANVIL_RPC $PRIVATE_KEY
   
fi
     exit 0
}

function simulatePassProp() {
forge script script/testScripts/gov/helpers/PassAnvilProp.s.sol:PassAnvilProp -s $1 --rpc-url $2  --private-key $3
}

function broadcastPassProp() {
forge script script/testScripts/gov/helpers/PassAnvilProp.s.sol:PassAnvilProp -s $1 --rpc-url $2 --private-key $3 --broadcast
}

function display_help() {
            echo "Usage:"
            echo " yarn propose:pass [options] [proposal Path] "
            echo " available options: [-d (delegates votes), --rpc-call (makes an rpc call, e.g. anvil_mine to mine n number of blocks)]"
            echo " the path to the proposal to be passed"
            echo ""
            echo "Examples:"
            echo "yarn propose:pass /gov-output/arb-sepolia/67531219-add-collateral-proposal.json"
            echo "yarn propose:pass --delegate /gov-output/arb-sepolia/67531219-add-collateral-proposal.json"
            echo "yarn propose:pass --rpc-call anvil_mine 2"
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

      -a | --add-options)
          # do something here call function
          # and write it in your help function display_help()
           shift 2
           ;;
        -r | --rpc-call)
          makeCall $2 $3
          ;;
        -d | --delegate)
        delegate $2
        ;;
      -q | --queue)
        queue $2
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


#######################
# Check if parameter  #
# is set then execute #
#######################

if [[ $1 != "" && $2 == "" ]]; then passProp $1
        elif [[ $1 == "do-all" ]]; then makeCall $2 $3
    else 
    display_help

fi

exit 0;