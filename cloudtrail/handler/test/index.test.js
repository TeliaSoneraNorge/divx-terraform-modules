const test = require('tape'),
      sinon = require('sinon'),
      handler = require('../index.js');

var unzip_stub = sinon.stub(handler, 'unzip').callsFake((input) => input);
var put_item_stub = sinon.stub(handler, 'put_item').callsFake((input) => input);

const example = {
    eventID: 'sampleEventID',
    eventName: 'eventName',
    eventTime: 'sampleEventTime',
    userIdentity: {},
    responseElements: {
        credentials: {}
    }
};

test('parse() should parse both the input and the nested logEvents', (assert) => {
    let sample = JSON.stringify({
        'logEvents': [
            JSON.stringify(example)
        ]
    }, null, 2);

    handler.parse(sample).then((result) => {
            assert.deepEqual(result, [example]);
            assert.end();
        })
        .catch((err) => {
            assert.fail(`Unexpected failure: ${err.message}`);
            assert.end();
        });
});

test('parse() should remove logEvents that fail to parse in the resulting array', (assert) => {
    let sample = JSON.stringify({
        logEvents: [
            JSON.stringify(example),
            'invalid {'
        ]
    });

    handler.parse(sample).then((result) => {
            assert.deepEqual(result, [example]);
            assert.end();
        })
        .catch((err) => {
            assert.fail(`Unexpected failure: ${err.message}`);
            assert.end();
        });
});

test('parse() should reject if it is not able to return any parsed events', (assert) => {
    let sample = JSON.stringify({
        logEvents: [
            'invalid {'
        ]
    });

    handler.parse(sample).then((result) => {
            assert.fail('Unexpected success. Should not resolve when no parsed logEvents can be returned.');
            assert.end();
        })
        .catch((err) => {
            assert.pass();
            assert.end();
        });
});

test('parse() should reject if it fails to parse the input at all', (assert) => {
    let sample = 'invalid {';

    handler.parse(sample).then((result) => {
            assert.fail('Unexpected success. Should not resolve when JSON input is invalid.');
            assert.end();
        })
        .catch((err) => {
            assert.pass();
            assert.end();
        });
});

test('process() should include the hash and range keys for dynamodb', (assert) => {
    let sample = [example];

    handler.process(sample).then((result) => {
            assert.equal(typeof(result), 'object');
            assert.true(result[0].hasOwnProperty('eventID'));
            assert.true(result[0].hasOwnProperty('eventTime'));
            assert.end();
        })
        .catch((err) => {
            assert.fail('Unexpected failure: ${err.message}');
            assert.end();
        });
});

test('create_item() should include the username if it exists', (assert) => {
    let sample = example,
        user = 'sampleUserName';
    sample.userIdentity['userName'] = user;
    let result = handler.create_item(sample);

    assert.equal(result.user, user);
    assert.end();
});

test('create_item() lists the temporary accessKeyId for AssumeRole', (assert) => {
    let sample = example,
        key = 'sampleKey';
    sample.eventName = 'AssumeRole';
    sample.responseElements.credentials['accessKeyId'] = key;
    let result = handler.create_item(sample);

    assert.equal(result.accessKeyId, key);
    assert.end();
});

test('create_item() lists accessKeyId used to authenticate for non-assumeRole actions', (assert) => {
    let sample = example,
        key = 'sampleKey';
    sample.userIdentity['accessKeyId'] = key;
    let result = handler.create_item(sample);

    assert.equal(result.accessKeyId, key);
    assert.end();
});
