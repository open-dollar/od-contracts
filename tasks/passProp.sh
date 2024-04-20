#!/bin/bash
source .env

set -e

######################
## GLOBAL VARIABLES ##
######################

    RPC_ENDPOINT=""
    PRIVATE_KEY=""

###############
## FUNCTIONS ##
###############



function vote(){
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
      simulate "PassAnvilProp" $CALLDATA  $ANVIL_RPC  $PRIVATE_KEY

      read -p "Please verify the data and confirm that you want to pass this proposal (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Passing proposal on Anvil..."
        FOUNDRY_PROFILE=governance 
        broadcast "PassAnvilProp" $CALLDATA $ANVIL_RPC $PRIVATE_KEY
   
fi
}

function queue(){
    declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
      NETWORK=${OUTPUT[0]}
      CAST_PATH=${OUTPUT[1]}
      getRpcAndPk $NETWORK
      CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
     
     forge script script/testScripts/gov/QueueProposal.s.sol:QueueProposal -s $CALLDATA --rpc-url $RPC_ENDPOINT  --private-key $PRIVATE_KEY

     read -p "Please verify the data and confirm that you want to pass this proposal (y/n):" CONFIRMATION
     if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Passing proposal on Anvil..."
         forge script script/testScripts/gov/QueueProposal.s.sol:QueueProposal -s $CALLDATA --rpc-url $RPC_ENDPOINT --private-key $PRIVATE_KEY --broadcast
    fi
}

function generateProposal(){
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
    NETWORK=${OUTPUT[0]}
    CAST_PATH=${OUTPUT[1]}

    getRpcAndPk $NETWORK
    
    CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
      
    COMMAND_PATH=$(node tasks/parseProposalPath.js $1)

    CALLDATA=$(cast calldata "run(string)" $CAST_PATH)

      FOUNDRY_PROFILE=governance forge script $COMMAND_PATH -s $CALLDATA --rpc-url $RPC_ENDPOINT
}

function delegate(){
    declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
    NETWORK=${OUTPUT[0]}
    CAST_PATH=${OUTPUT[1]}
    getRpcAndPk $NETWORK

    CALLDATA=$(cast calldata "delegateTokens(string)" $CAST_PATH)

        simulate "PassAnvilProp" $CALLDATA  $ANVIL_RPC  $PRIVATE_KEY

     read -p "Please verify the data and confirm that you want to pass this proposal (y/n):" CONFIRMATION
     if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Passing proposal on Anvil..."
         broadcast "PassAnvilProp"  $CALLDATA $ANVIL_RPC $PRIVATE_KEY
   
fi
}

function simulate() {
  forge script $1 -s $2 --rpc-url $3  --private-key $4
}

function broadcast() {
  forge script $1 -s $2 --rpc-url $3 --private-key $4 --broadcast
}

function display_help() {
            echo ""
            echo " Manage your governance proposals!"
            echo ""
            echo " `tput smul`Usage:`tput sgr0` yarn propose [option flag] [proposal Path]"
            echo ""
            echo " `tput smul`Options:`tput sgr0` "
            echo "-h, --help                        Print help"
            echo "-d, --delegate                    Delegate your votes uses gov-input path or gov-output path    |  example: propose -d gov-input/anvil/new-ModifyParameters.json          ***only works on anvil***"
            echo "-g, --generate                    Generate your proposal from the simple input json             |  example: propose -g gov-input/anvil/new-ModifyParameters.json"
            echo "-s, --submit                      Submit your proposal with the generated gov-output path       |  example: propose -s gov-output/anvil/38642346-modifyParameters.json"
            echo "-r, --rpc-call                    Make an rpc call make sure to add any necessary arguments     |  example: propose -r anvil_mine 2                                       ***only works on anvil***"
            echo "-v, --vote                        Vote for your submitted proposal                              |  example: propose -v gov-output/anvil/38642346-modifyParameters.json"
            echo "-q, --queue                       Queue your passed proposal                                    |  example: propose -q gov-output/anvil/38642346-modifyParameters.json"
            echo "-x, --execute                     Execute your queued proposal                                  |  example: propose -x gov-output/anvil/38642346-modifyParameters.json"
            echo "-sve, --submit-vote-execute   Submit, mine, vote, mine, queue, mine, execute.               |  example: propose -sve gov-output/anvil/38642346-modifyParameters.json  ***only works on anvil***"
            echo ""
        exit 0
}

function submit(){
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}
    CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
        getRpcAndPk $NETWORK

      FOUNDRY_PROFILE=governance 
      simulate "Proposer" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

      read -p "Please verify the data and confirm the submission of this proposal (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Executing..."
        FOUNDRY_PROFILE=governance 
        broadcast "Proposer" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY
   
fi
}

function makeCall() {
    node ./tasks/anvilRPCCalls.js $1 $2
}

function getRpcAndPk() {
      if [[ $1 = "arb-sepolia" || $1 = "sepolia" ]]; then RPC_ENDPOINT=$ARB_SEPOLIA_RPC PRIVATE_KEY=$ARB_SEPOLIA_PK
          elif [[ $1 = "anvil" ]]; then RPC_ENDPOINT=$ANVIL_RPC PRIVATE_KEY=$ANVIL_ONE
          elif [[ $1 = "arb-mainnet" || $1 = "mainnet" ]]; then RPC_ENDPOINT=$ARB_MAINNET_RPC PRIVATE_KEY=$ARB_MAINNET_PK
          else
            echo "Unrecognized target environment"
            exit 1    
      fi
}

function execute(){
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}
  CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
    getRpcAndPk $NETWORK
      FOUNDRY_PROFILE=governance
      simulate "Executor" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

      read -p "Please verify the data and confirm the submission of this proposal (y/n):" CONFIRMATION

if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]
    then
        echo "Executing..."
        FOUNDRY_PROFILE=governance
        broadcast "Executor" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY
   
fi
}

function submitVoteAndExecute() {
    makeCall "anvil_mine" 2
    submit $1
    makeCall "anvil_mine" 2
    vote $1
    makeCall "anvil_mine" 16
    queue $1
    makeCall "anvil_mine" 50
    execute $1
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
          exit 0
          ;;
      -d | --delegate)
          delegate $2
          exit 0
          ;;
      -q | --queue)
          queue $2
          exit 0
          ;;
      -s | --submit)
          submit $2
          exit 0
          ;;
      -v | --vote)
          vote $2
          exit 0
          ;;
      -g | --generate)
          generateProposal $2
          exit 0
          ;;
      -x | --execute)
          execute $2
          exit 0
          ;;
      -sve | --submit-vote-execute)
        submitVoteAndExecute $2
          exit 0
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

if [[ $1 != "" && $2 == "" ]]; then display_help $1
    else 
    display_help

fi

exit 0;