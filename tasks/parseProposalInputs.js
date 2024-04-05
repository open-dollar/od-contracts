const fs = require("fs");
const path = require("path");
const {findAddress} = require("./findContractAddress.js");

const args = process.argv.slice(2);
const targetEnv = args[0];
const proposalType = args[1].toLowerCase();
console.log(args)
const inputs = args.slice(2);


switch(proposalType) {
    case 'addcollateral':
        if(inputs.length < 6){console.error('incorrect number of input params', inputs[4])}
        const governorContract = findAddress(targetEnv, "ODGovernor_Address");
        const globalSettlement = findAddress(targetEnv, "GlobalSettlement_Address");

        const proposal = {
            ODGovernor : governorContract.address,
            GlobalSettlement: globalSettlement.address,
            NewCollateralType: inputs[0],
            NewCollateralAddress: inputs[1],
            MinimumBid: inputs[2],
            MinimumDiscount: inputs[3],
            MaximumDiscount: inputs[4],
            PerSecondDiscountUpdateRate: inputs[5],
        }

        const outputPath = path.join(__dirname, "../gov-input/new-addCollateral-prop.json");

        fs.writeFile(outputPath, JSON.stringify(proposal, null, 2), (err) => {
            if (err) {
              console.error(err);
              return;
            }
        
            console.log("new-addCollateral-prop.json written to file successfully!");
        });
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