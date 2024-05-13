const path = require('path');
const fse = require('fs-extra');

const transformRemappings = (file, filePath) => {
    const fileLines = file.split('\n');

    // Initialize remappings array to an empty array
    let remappings = [];

    try {
        if (fse.existsSync('remappings.txt')) {
            // Attempt to read the remappings file
            const remappingsContent = fse.readFileSync('remappings.txt', 'utf8');

            // Parse the content and filter empty lines
            remappings = remappingsContent
                .split('\n')
                .filter(Boolean)
                .map(line => line.trim().split('='));
        } else {
            return '';
        }
    } catch (error) {
        // Handle the error when the file does not exist or cannot be read
        console.error('Error reading remappings file:', error);
    }

    return fileLines
        .map(line => {
            // Just modify imports
            if (!line.match(/^\s*import|} from '/g)) return line;

            const remapping = remappings.find(([find]) => line.match(find))

            const modulesKey = 'node_modules/';

            if (!remapping) {
                // Transform:
                // import '../../../node_modules/some-file.sol';
                // into:
                // import 'some-file.sol';

                if (line.includes(modulesKey)) {
                    line = `import '` + line.substring(line.indexOf(modulesKey) + modulesKey.length);
                } else {
                    return line;
                }

                return line;
            }

            // Skip remapping dependencies eg. @openzeppelin
            // eslint-disable @typescript-eslint/no-unsafe-call
            if (remapping && remapping[1].includes(modulesKey)) return line;

            const [keep, existingPath] = line.split(`'`);
            const fileName = existingPath.split(remapping[0])[1]

            const remappingDestination = path.relative(filePath, remapping[1]);

            const newPath = path.join(remappingDestination, fileName)

            // path.relative assumes arguments are directories, so we must correct
            const dds = newPath.split("../").length - 1
            let adjustedPath = newPath
            if (dds === 1) adjustedPath = adjustedPath.substring(1) // replace "../" with "./"
            else if (dds > 1) adjustedPath = adjustedPath.substring(3)   // replace "../../" with "../"

            line = `${keep}'${adjustedPath}';`
            // console.log(existingPath, newPath, line);
            return line;
        })
        .join('\n');
};

const run = () => {
    // const filePath = "src/contracts/LiquidationEngine.sol"
    // const filePath = "src/contracts/settlement/GlobalSettlement.sol"
    // const filePath = "src/contracts/settlement/PostSettlementSurplusAuctionHouse.sol"
    const filePath = "test/e2e/Common.t.sol"
    const fileContents = fse.readFileSync(filePath, 'utf8');
    console.log(transformRemappings(fileContents, filePath).substring(0, 1000))
}
run();