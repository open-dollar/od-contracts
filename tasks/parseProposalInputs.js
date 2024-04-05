const fs = require("fs");
const path = require("path");
const {findAddress} = require("./findContractAddress.js");

const args = process.argv.slice(2);
const targetEnv = args[0];
const proposalType = args[1].toLowerCase();
const inputs = args.slice(2);


switch(proposalType) {
    case 'addcollateral':
        const outputPath = path.join(__dirname, "../gov-input/new-addCollateral-prop.json");
        const currentProp = JSON.parse(fs.readFileSync(outputPath));

        let newInputs = {};
        for( let i = 0; i< 6; i++){
        
            if(i==0){
                inputs[i].length > 1 ? newInputs["cType"] = inputs[0] : newInputs["cType"] = currentProp[NewCollateralType];
            } else if(i==1) {
                inputs[i].length > 1 ? newInputs["newCAddress"] = inputs[1] : newInputs["newCAddress"] = currentProp[NewCollateralAddress];
            } else if (i==2){
                inputs[i].length > 1 ? newInputs["minBid"] = inputs[2] : newInputs["minBid"] = currentProp[MinimumBid];
            } else if (i==3){
                inputs[i].length > 1 ? newInputs["minDiscount"] = inputs[3] : newInputs["minDiscount"] = currentProp[MinimumDiscount];
            }else if (i==4){
                inputs[i].length > 1 ? newInputs["maxDiscount"] = inputs[4] : newInputs["maxDiscount"] = currentProp[MaximumDiscount];
            }else if (i==5){
                inputs[i].length > 1 ? newInputs["perSecondRate"] = inputs[5] : newInputs["perSecondRate"] = currentProp[PerSecondDiscountUpdateRate];
            }
     
        }

        const governorContract = findAddress(targetEnv, "ODGovernor_Address");
        const globalSettlement = findAddress(targetEnv, "GlobalSettlement_Address");

        const proposal = {
            ODGovernor : governorContract.address,
            GlobalSettlement: globalSettlement.address,
            NewCollateralType: newInputs.cType,
            NewCollateralAddress: newInputs.newCAddress,
            MinimumBid: newInputs.minBid,
            MinimumDiscount: newInputs.minDiscount,
            MaximumDiscount: newInputs.maxDiscount,
            PerSecondDiscountUpdateRate: newInputs.perSecondRate,
        }

        

        fs.writeFile(outputPath, JSON.stringify(proposal, null, 2), (err) => {
            if (err) {
              console.error(err);
              return;
            }
        
            console.log("new-addCollateral-prop.json written to file successfully!");
        });
    // } else {
    //     console.error("please use 6 input variables in this order: [new collateral type] [new collateral address] [minimum bid] [minimum discount] [maximum discount] [per second discount update rate]")
    //     console.log("set variable as '_' to use default variables eg: _ _ _ 1000000 _ _");
    // }
    break;

    case 'transfererc20':
    console.log('transfer erc20');
    break;

    case 'updateblockdelay':
    console.log('updateblockdelay')
    break;

    case 'updatenftrenderer':
    console.log('updatenftrenderer')
    break;

    case 'updatetimedelay':
    console.log('updatetimedelay')
    break;

    case 'updatepidcontroller':
    console.log('updatepidcontroller')
    break;

    case 'updateparameter':
    console.log('updateparameter')
    break;

    default:
        console.log('unrecognized proposal type');
}

return;