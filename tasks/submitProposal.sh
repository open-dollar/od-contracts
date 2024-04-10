#!/bin/bash
source .env

set -e

###############
## FUNCTIONS ##
###############

function submitAddCollateral(){
    NETWORK="$1"
    PROPOSAL_JSON=$(node tasks/parseProposalOutputs.js $1 "addCollateral")
    CALLDATA=$(cast calldata "run(string)" $PROPOSAL_JSON)
    
    if [[ $1 == "sepolia" ]]
        then
    PRIVATE_KEY=$ARB_SEPOLIA_PK forge script script/testScripts/gov/AddCollateralAction/ProposeAddCollateral.s.sol:ProposeAddCollateral -s $CALLDATA --rpc-url $ARB_SEPOLIA_RPC
    fi 
    
}

function submitERC20Transfer(){
    NETWORK=$1
    INPUTS=$3
}

function submitUpdateNFTRenderer(){
    NETWORK=$1
    INPUTS=$3
}

function submitUpdateTimeDelay(){
    NETWORK=$1
    INPUTS=$3
}

function submitUpdatePidController() {
    NETWORK=$1
    INPUTS=$3
}

function submitUpdateParameter() {
    NETWORK=$1
    INPUTS=$3
}

function display_help() {
    echo "HELP!"
}

while :
do
    case "$1" in
      "")
            echo "Usage:"
            echo " yarn script:propose:submit [target environment] [proposalType] "
            echo "    where target environment (required): anvil / sepolia / mainnet"
            echo "    the type of proposal to be generated"
            echo "    your inputs in the correct order.  use --help for more info"
            echo ""
            echo "Example:"
            echo "yarn script:propose:submit sepolia addCollateral ARB 0xNewCollateralTokenAddress 5e18 1e18 1e18 999998607628240588157433861"
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
case "$2" in
  addCollateral | addcollateral)
    submitAddCollateral $1 
    ;;
  transferERC20 | transfer | transfererc20)
    submitERC20Transfer
    ;;
  updateBlockDelay | updateblockdelay)
    submitUpdateBlockDelay
    ;;
  updateNFTRenderer | updatenftrenderer)
    submitUpdateNFTRenderer
    ;;
  updateTimeDelay | updatetimedelay)
    submitUpdateTimeDelay
    ;;
  updatePIDController | updatepidcontroller)
    submitUpdatePidController
    ;;
  updateParameter | updateparameter)
    submitUpdateParameter
    ;;
  *)
#    echo "Usage: $0 {start|stop|restart}" >&2
     display_help

     exit 1
     ;;
esac

