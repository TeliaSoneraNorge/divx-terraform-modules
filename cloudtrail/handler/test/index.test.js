const test = require('tape'),
    sinon = require('sinon'),
    handler = require('../index.js');

// zlib wrapper function
var unzip_stub = sinon.stub(handler, 'unzip');
unzip_stub.callsFake((input) => Promise.resolve(input));

// aws-sdk wrapper function
var put_item_stub = sinon.stub(handler, 'put_item');
put_item_stub.callsFake((input) => Promise.resolve(input));

const event = {
    eventID: '099ff820-00f2-4500-94fc-2b9da26d576f',
    eventName: 'ListBuckets',
    eventTime: '2016-04-05T20:39:39Z',
    eventType: 'AwsApiCall',
    userIdentity: {
        accessKeyId: 'used_key'
    },
    responseElements: {
        credentials: {
            accessKeyId: 'temporary_key'
        }
    }
};

function serialize(sample) {
    return JSON.stringify({
        logEvents: sample.map(JSON.stringify)
    });
}

test('process() should return an array', (assert) => {
    let input = serialize([event]);
    handler.process(input).then((result) => {
            assert.true(result instanceof Array);
            assert.end();
        })
        .catch((err) => {
            assert.fail(`Unexpected failure: ${err.message}\n${err.stack}`);
            assert.end();
        });
});

test('process() should include the hash and range keys for dynamodb', (assert) => {
    let input = serialize([event]);
    handler.process(input).then((result) => {
            assert.true(result[0].hasOwnProperty('eventID'));
            assert.true(result[0].hasOwnProperty('eventTime'));
            assert.end();
        })
        .catch((err) => {
            assert.fail(`Unexpected failure: ${err.message}\n${err.stack}`);
            assert.end();
        });
});

test('process() should include the username if it exists', (assert) => {
    let sample = event,
        user = 'some.user';

    sample.userIdentity['userName'] = user;
    let input = serialize([sample]);

    handler.process(input).then((result) => {
            assert.equal(result[0].user, user);
            assert.end();
        })
        .catch((err) => {
            assert.fail(`Unexpected failure: ${err.message}\n${err.stack}`);
            assert.end();
        });
});

test('process() lists the accessKeyId used to authenticate for non-assumeRole actions', (assert) => {
    let input = serialize([event]);

    handler.process(input).then((result) => {
            assert.equal(result[0].accessKeyId, 'used_key');
            assert.end();
        })
        .catch((err) => {
            assert.fail(`Unexpected failure: ${err.message}\n${err.stack}`);
            assert.end();
        });
});

test('process() lists the temporary accessKeyId for AssumeRole', (assert) => {
    let sample = event;
    sample.eventName = 'AssumeRole';
    let input = serialize([sample]);

    handler.process(input).then((result) => {
            assert.equal(result[0].accessKeyId, 'temporary_key');
            assert.end();
        })
        .catch((err) => {
            assert.fail(`Unexpected failure: ${err.message}\n${err.stack}`);
            assert.end();
        });
});
