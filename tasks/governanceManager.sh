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

function delimitier() {
  echo '#################################################'
}

function vote() {
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}
  CALLDATA=$(cast calldata "vote(string)" $CAST_PATH)

  getRpcAndPk $NETWORK

  echo "Simulating... "

  simulate "GovernanceHelpers" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

  delimitier
  echo "VOTING"
  read -p "Please verify the data and confirm that you want to Vote on this proposal (y/n): " CONFIRMATION

  if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]; then
    echo "Voting for proposal on $NETWORK..."
    broadcast "GovernanceHelpers" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY
  fi
}

function queue() {
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}
  CALLDATA=$(cast calldata "run(string)" $CAST_PATH)

  getRpcAndPk $NETWORK

  simulate "QueueProposal" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

  delimitier
  echo "QUEUEING..."
  read -p "Please verify the data and confirm that you want to queue this proposal (y/n): " CONFIRMATION

  if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]; then
    echo "Queuing your proposal..."
    broadcast "QueueProposal" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY
  fi
}

function generateProposal() {
  echo "Generating..."
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}

  getRpcAndPk $NETWORK

  COMMAND_PATH=$(node tasks/parseProposalPath.js $1)
  echo "$COMMAND_PATH"
  CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
  forge script $COMMAND_PATH -s $CALLDATA --fork-url $ARB_MAINNET_RPC --unlocked 0x7a528ea3e06d85ed1c22219471cf0b1851943903
  # simulate $COMMAND_PATH $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

}

function delegate() {
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}
  getRpcAndPk $NETWORK

  CALLDATA=$(cast calldata "delegateTokens(string)" $CAST_PATH)

  simulate "GovernanceHelpers" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY
  delimitier
  echo "DELEGATING"
  read -p "Please verify the data and confirm that you want to delegate your tokens (y/n): " CONFIRMATION
  if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]; then
    echo "Delegating your tokens..."
    broadcast "GovernanceHelpers" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

  fi
}

function simulate() {
  forge script $1 -s $2 --rpc-url $3 --private-key $4
}

function broadcast() {
  forge script $1 -s $2 --rpc-url $3 --private-key $4 --broadcast
}

function display_help() {
  echo ""
  echo " Manage your governance proposals!"
  echo ""
  echo " The correct proposing and voting order is:"
  echo " 1. Generate the proposal."
  echo " 2. Delegate your tokens."
  echo " 3. Submit your proposal."
  echo " 4. After enough time has passed, Vote on your proposal."
  echo " 5. If your proposal passes you can queue it to be executed."
  echo " 6. After enough time has passed you can execute it."

  echo " $(tput smul)Usage:$(tput sgr0) yarn propose [command flag] [option flag] [proposal Path]"
  echo ""
  echo " $(tput smul)Commands:$(tput sgr0) "
  echo " -h, --help                        Print help"
  echo " -g, --generate                    Generate your proposal from the simple input json             |  example: propose -g gov-input/anvil/new-ModifyParameters.json"
  echo " -d, --delegate                    Delegate your votes. uses gov-output path                     |  example: propose -d gov-output/anvil/38642346-modifyParameters.json"
  echo " -s, --submit                      Submit your proposal with the generated gov-output path       |  example: propose -s gov-output/anvil/38642346-modifyParameters.json"
  echo " -v, --vote                        Vote for your submitted proposal                              |  example: propose -v gov-output/anvil/38642346-modifyParameters.json"
  echo " -q, --queue                       Queue your passed proposal                                    |  example: propose -q gov-output/anvil/38642346-modifyParameters.json"
  echo " -x, --execute                     Execute your queued proposal                                  |  example: propose -x gov-output/anvil/38642346-modifyParameters.json"
  echo ""
  echo " $(tput smul)Options:$(tput sgr0) "
  echo ""
  echo " -a, --auto              Add to the -g flag in order to automatically insert available addresses | example: propose -g -a gov-input/anvil/new-ModifyParameters.json"
  echo ""
  echo " $(tput smul)Anvil only commands:$(tput sgr0) "
  echo " -r, --rpc-call                    Make an rpc call make sure to add any necessary arguments     |  example: propose -r anvil_mine 2"
  echo " -sve, --submit-vote-execute       Submit, mine, vote, mine, queue, mine, execute.               |  example: propose -sve gov-output/anvil/38642346-modifyParameters.json"
  echo ""
  exit 0
}

function submit() {
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}
  CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
  getRpcAndPk $NETWORK

  FOUNDRY_PROFILE=governance
  simulate "Proposer" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY
  delimitier
  echo " SUBMITTING"
  read -p "Please verify the data and confirm the submission of this proposal (y/n): " CONFIRMATION

  if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]; then
    echo "Executing..."
    FOUNDRY_PROFILE=governance
    broadcast "Proposer" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

  fi
}

function makeCall() {
  node ./tasks/anvilRPCCalls.js $1 $2
}

function getRpcAndPk() {
  if [[ $1 = "arb-sepolia" || $1 = "sepolia" ]]; then
    RPC_ENDPOINT=$ARB_SEPOLIA_RPC PRIVATE_KEY=$ARB_SEPOLIA_PK
  elif [[ $1 = "anvil" ]]; then
    RPC_ENDPOINT=$ANVIL_RPC PRIVATE_KEY=$ANVIL_ONE
  elif [[ $1 = "arb-mainnet" || $1 = "mainnet" ]]; then
    RPC_ENDPOINT=$ARB_MAINNET_RPC PRIVATE_KEY=$ARB_MAINNET_PK
  else
    echo "Unrecognized target environment"
    exit 1
  fi
}

function execute() {
  declare OUTPUT=($(node ./tasks/parseNetwork.js $1))
  NETWORK=${OUTPUT[0]}
  CAST_PATH=${OUTPUT[1]}
  CALLDATA=$(cast calldata "run(string)" $CAST_PATH)
  getRpcAndPk $NETWORK
  FOUNDRY_PROFILE=governance
  simulate "Executor" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY
  delimitier
  echo "EXECUTING"
  read -p "Please verify the data and confirm the execution of this proposal (y/n): " CONFIRMATION

  if [[ $CONFIRMATION == "y" || $CONFIRMATION == "Y" ]]; then
    echo "Executing..."
    FOUNDRY_PROFILE=governance
    broadcast "Executor" $CALLDATA $RPC_ENDPOINT $PRIVATE_KEY

  fi
}

function checkPath() {
  if [[ $1 == "" ]]; then
    display_help
  fi
}

function submitVoteAndExecute() {
  makeCall "anvil_mine" 2
  submit $1
  makeCall "anvil_mine" 2
  vote $1
  makeCall "anvil_mine" 16
  queue $1
  makeCall "anvil_mine" 61
  execute $1
}

function findAndAddAddresses() {
  node ./tasks/findContractAddress.js $1
}

function cleanInputs() {
  node ./tasks/cleanInput.js $1

}

while :; do
  case "$1" in
  "")
    display_help
    ;;
  -h | -\? | --help)
    display_help
    ;;
  -r | --rpc-call)
    checkPath $2
    makeCall $2 $3
    exit 0
    ;;
  -d | --delegate)
    checkPath $2
    delegate $2
    exit 0
    ;;
  -q | --queue)
    checkPath $2
    queue $2
    exit 0
    ;;
  -s | --submit)
    checkPath $2
    submit $2
    exit 0
    ;;
  -v | --vote)
    checkPath $2
    vote $2
    exit 0
    ;;
  -g | --generate)
    if [[ $2 == "--auto" || $2 == "-a" ]]; then
      checkPath $3
      findAndAddAddresses $3
      generateProposal $3
      cleanInputs $3
    else
      checkPath $2
      generateProposal $2
    fi
    exit 0
    ;;
  -x | --execute)
    checkPath $2
    execute $2
    exit 0
    ;;
  -sve | --submit-vote-execute)
    checkPath $2
    submitVoteAndExecute $2
    exit 0
    ;;
  --) # End of all options
    shift
    break
    ;;
  -*)
    echo "Error: Unknown option: $1" >&2
    exit 1
    ;;
  *) # No more options
    break
    ;;
  esac
done

#######################
# Check if parameters #
# are set             #
#######################

if [[ $1 != "" && $2 == "" ]]; then
  display_help $1
fi

exit 0
