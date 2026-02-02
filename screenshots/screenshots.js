#!/usr/bin/env node
let yargs

try {
    yargs = require('yargs/yargs')
    require('puppeteer')
} catch(e) {
    console.log('FATAL: Missing dependencies - run "yarn install" in screenshots directory')
    return 1
}

const {hideBin} = require('yargs/helpers')
const frontend = require('./src/frontend')

const generateCommand = (yargs) => {
    // noinspection BadExpressionStatementJS
    yargs
        .positional('baseUrl', {
            description: 'The URL of the DfT LDAP website frontend',
            type: 'string'
        })
        .positional('outputDir', {
            description: 'Output directory',
            type: 'string',
        })
        .strictCommands()
        .strictOptions();
}

// noinspection BadExpressionStatementJS
yargs(hideBin(process.argv))
    .usage('usage: $0 <command>')
    .command('frontend <baseUrl> <outputDir>', 'Generates screenshots of the LDAP website frontend', yargs => generateCommand(yargs, false), argv => frontend.run(argv))
    .demandCommand(1)
    .help()
    .argv
