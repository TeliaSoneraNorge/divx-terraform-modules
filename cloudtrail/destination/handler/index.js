'use strict';

const zlib = require('zlib');
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

/**
 * Unzip data from CloudWatch.
 * @param {Object} input - The input passed to the Lambda function.
 * @return {Promise} The unzipped data from the input.
 */
exports.unzip = (input) => {
    return new Promise((resolve, reject) => {
        let payload = new Buffer(input.awslogs.data, 'base64');
        zlib.gunzip(payload, (err, data) => {
            if (err) {
                return reject(err);
            }
            return resolve(data.toString('ascii'));
        });
    });
};

/**
 * Parse Cloudwatch log events from (unzipped) data.
 * @param {String} data - The unzipped input from CloudWatch.
 * @return {Promise} An array with the parsed log events.
 */
exports.parse = (data) => {
    // Using a promise here for error handling.
    return new Promise((resolve, reject) => {
        var parsed = JSON.parse(data);
        let events = parsed.logEvents.map((event) => {
                try {
                    return JSON.parse(event.message);
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
};

/**
 * Takes an event and 'itemize' it for our CloudTrail table in DynamoDB.
 * @param {Object} event - A parsed log event.
 * @return {Object} The serialized item.
 */
exports.itemize_event = (event) => {
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
};

/**
 * Put a (serialized) item into DynamoDB.
 * @param {Object} item - A serialized event.
 * @return {Promise}
 */
exports.put_item = (item) => {
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
};

/**
 * Process the input and insert parsed events into DynamoDB.
 * @param {Object} input - The input to Lambda.
 * @return {Promise}
 */
exports.process = (input) => {
    return Promise.resolve(input)
        .then(exports.unzip)
        .then(exports.parse)
        .then((events) => {
            let results = events.map((event) => {
                let item = exports.itemize_event(event);
                return exports.put_item(item)
                    .then((result) => {
                        if (item.user !== 'none') {
                            console.info(`[INFO] Successfully added event for ${item.user} with key: ${item.accessKeyId}`);
                        } else {
                            console.info(`[INFO] Successfully added event: ${item.eventID}.`);
                        }
                        return result;
                    })
                    .catch((err) => {
                        // NOTE: We should tolerate failures for events (not an invocation error).
                        console.warn(`[WARN] Failed to add event: ${item.eventID}. Cause: ${err.message}`);
                        return null;
                    });
            });
            return Promise.all(results);
        });
};

exports.handler = (input, context, callback) => {
    exports.process(input)
        .then((output) => {
            callback(null, output);
        })
        .catch((err) => {
            callback(err, null);
        });
};
