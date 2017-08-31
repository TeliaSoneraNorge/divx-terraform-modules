'use strict';

const zlib = require('zlib');
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

/**
 * Unzip input from CloudWatch.
 * @param {Object} input - The input passed to the Lambda function.
 * @return {Promise} The unzipped data from the input.
 */
function unzip(input) {
    return new Promise((resolve, reject) => {
        let payload = new Buffer(input.awslogs.data, 'base64');
        zlib.gunzip(payload, (err, data) => {
            if (err) {
                return reject(err);
            }
            return resolve(data.toString('ascii'));
        });
    });
}

/**
 * Parse log events from the (unzipped) input.
 * @param {String} input - The unzipped input.
 * @return {Promise} Returns the parsed log events.
 */
function parse(input) {
    // Using a promise here for error handling.
    return new Promise((resolve, reject) => {
        try {
            var parsed = JSON.parse(input);
        } catch (err) {
            return reject(err);
        }
        let events = parsed.logEvents.map((event) => {
                try {
                    return JSON.parse(event);
                } catch (err) {
                    return null;
                }
            })
            .filter((event) => event !== null);
        if (events.length < 1) {
            return reject(new Error('No events to process after parsing input.'));
        }
        return resolve(events);
    });
}

/**
 * Create an item which can be inserted into DynamoDB. (TTL set to 90 days).
 * @param {Object} event - The parsed event.
 * @return {Object} The finished item.
 */
function create_item(event) {
    let item = {
        "eventID": event.eventID,
        "eventTime": event.eventTime,
        "accessKeyId": "none",
        "user": "none",
        "event": JSON.stringify(event, null, 2),
        "ttl": Math.floor(Date.now() / 1000) + (3600 * 24 * 90)
    };

    if (event.userIdentity.hasOwnProperty('userName')) {
        item['user'] = event.userIdentity.userName;
    }

    // Add accessKeyId as an attribute.
    // (For AssumeRole calls we show the temporary key returned from the call.)
    if (event.eventName === 'AssumeRole') {
        item['accessKeyId'] = event.responseElements.credentials.accessKeyId;
    } else if (event.userIdentity.hasOwnProperty('accessKeyId')) {
        item['accessKeyId'] = event.userIdentity.accessKeyId;
    }

    return item;
}

/**
 * Put and item in the DynamoDB table.
 * @param {Object} item - The item to put.
 * @return {Promise} Returns the output from DynamoDB.
 */
function put_item(item) {
    return new Promise((resolve, reject) => {
        dynamodb.put({
            TableName: process.env.DYNAMODB_TABLE_NAME,
            Item: item
        }, (err, data) => {
            if (err) {
                return reject(err);
            } else {
                return resolve(data);
            }
        });
    });
}

function handler(input, context, callback) {
    Promise.resolve(input)
        .then(unzip)
        .then(parse)
        .then((records) => {
            let events = records.map((event) => {
                let item = create_item(event);
                return put_item(item)
                    .then((data) => {
                        if (item.user !== 'none') {
                            console.info(`[INFO] Successfully added event for ${item.user} with key: ${item.accessKeyId}`);
                        } else {
                            console.info(`[INFO] Successfully added event: ${item.eventID}.`);
                        }
                        return data;
                    })
                    .catch((err) => {
                        // NOTE: We should tolerate failures for events (not an invocation error).
                        console.warn(`[WARN] Failed to add event: ${item.eventID}. Cause: ${err.message}`);
                        return null;
                    });
            });
            return Promise.all(events);
        })
        .then((output) => {
            callback(null, output);
        })
        .catch((err) => {
            callback(err, null);
        });
}

// Exporting helper functions for testing
module.exports = {
    parse,
    create_item,
    put_item,
    handler
};
