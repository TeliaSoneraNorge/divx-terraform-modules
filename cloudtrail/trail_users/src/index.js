'use strict';

const zlib = require('zlib');
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = (input, context) => {
    var payload = new Buffer(input.awslogs.data, 'base64');
    zlib.gunzip(payload, function(err, result) {
        if (err) {
            context.fail(err);
        } else {
            result = JSON.parse(result.toString('ascii'));
            result.logEvents.forEach((event) => {
                event = JSON.parse(event.message);
                let item = {
                    "AccessKeyId": event.responseElements.credentials.accessKeyId,
                    "Username": event.userIdentity.userName
                };

                dynamodb.put({
                    TableName: process.env.DYNAMODB_TABLE_NAME,
                    Item: item
                }, (err, data) => {
                    if (err) {
                        console.error("Unable to add item:", JSON.stringify(item, null, 2));
                        context.fail(err);
                    } else {
                        console.log("Successfully added item:", JSON.stringify(item, null, 2));
                        context.succeed();
                    }
                });
            });
        }
    });
};
