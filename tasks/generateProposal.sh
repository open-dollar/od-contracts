#!/bin/bash
source .env

set -e
###############
## FUNCTIONS ##
###############

function proposeAddCollateral(){
    NETWORK="$1"
    node tasks/parseProposalInputs.js $1 "addCollateral" $3 $4 $5 $6 $7 $8 $9
}

function proposeERC20Transfer(){
    NETWORK=$1
    INPUTS=$3
}

function proposeUpdateNFTRenderer(){
    NETWORK=$1
    INPUTS=$3
}

function proposeUpdateTimeDelay(){
    NETWORK=$1
    INPUTS=$3
}

function proposeUpdatePidController() {
    NETWORK=$1
    INPUTS=$3
}

function proposeUpdateParameter() {
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
            echo " yarn script:propose [target environment] [proposalType] [requiredInputs for that type]"
            echo "    where target environment (required): anvil / sepolia / mainnet"
            echo "    the type of proposal to be generated"
            echo "    an array of the needed inputs for that proposal type in format: [[inputName, input], [inputName2, input2]]"
            echo ""
            echo "Example:"
            echo " yarn script:propose sepolia addCollateral ARB 0xNewCollateralTokenAddress 5e18 1e18 1e18 999998607628240588157433861"
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
    proposeAddCollateral $1 $2 $3 $4 $5 $6 $7 $8
    ;;
  transferERC20 | transfer | transfererc20)
    proposeERC20Transfer
    ;;
  updateBlockDelay | updateblockdelay)
    proposeUpdateBlockDelay
    ;;
  updateNFTRenderer | updatenftrenderer)
    proposeUpdateNFTRenderer
    ;;
  updateTimeDelay | updatetimedelay)
    proposeUpdateTimeDelay
    ;;
  updatePIDController | updatepidcontroller)
    proposeUpdatePidController
    ;;
  updateParameter | updateparameter)
    proposeUpdateParameter
    ;;
  *)
#    echo "Usage: $0 {start|stop|restart}" >&2
     display_help

     exit 1
     ;;
esac

