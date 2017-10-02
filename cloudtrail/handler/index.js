'use strict';

const zlib = require('zlib');
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3({region: process.env.REGION});

/**
 * Read an object from an S3 bucket.
 * @param {Object} input - A record from an S3 event.
 * @return {Promise} The body of the object.
 */
exports.read = (record) => {
    let request = {
        Bucket: record.s3.bucket.name,
        Key: decodeURI(record.s3.object.key)
    };
    return new Promise((resolve, reject) => {
        s3.getObject(request, (err, data) => {
            if (err) {
                return reject(err);
            }
            return resolve(data.Body);
        });
    });
};

/**
 * Unzip data/body after reading from S3.
 * @param {Object} input - The input passed to the Lambda function.
 * @return {Promise} The unzipped data from the input.
 */
exports.unzip = (body) => {
    return new Promise((resolve, reject) => {
        let payload = new Buffer(body, 'base64');
        zlib.gunzip(payload, (err, data) => {
            if (err) {
                return reject(err);
            }
            return resolve(data.toString('ascii'));
        });
    });
};

/**
 * Parse records from the (unzipped) data.
 * @param {String} data - The unzipped logs.
 * @return {Promise} An array with the parsed log events.
 */
exports.parse = (data) => {
    // Using a promise here for error handling.
    return new Promise((resolve, reject) => {
        var parsed = JSON.parse(data);
        return resolve(parsed.Records);
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
        .then(exports.read)
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

exports.handler = (event, context, callback) => {
    let results = event.Records.forEach((record) => {
        return exports.process(record)
            .catch((err) => {
                console.error(`[ERROR] Failed to process record. Cause: ${err}. Record: ${JSON.stringify(record)}`);
            });
    });
};
