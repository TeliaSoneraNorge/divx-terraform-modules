## CloudTrail

This is a collection of modules for setting up CloudTrail for (primarily) auditing of cross-account roles, meaning
users who assumed a role and performed actions in another account, using a role. The cross account part is recommended,
but optional. I.e. the CloudWatch log group can be situated in the same account as the CloudTrail. 

The setup we want to achieve is as follows:
- Users are registered on a Jump account.
- They assume roles to work on different Dev accounts.
- Logs/audit trails from both Jump and Dev accounts are sent to a standalone logging account.
- The mapping between user and action happens on the logging account (which also keeps a full log history), and
the processed logs are made available to the Dev account.

### Setup

Because we have to set up CloudTrail on both the Jump and Dev accounts, in addition to the logging account, the 
process requires several steps to complete. Each step is divided into different submodules:

On the Log account we need the following:

- `trail_users`: A set of resources set up to handle an incoming CloudTrail from the Jump account.
- `trail_actions`: Resources which handle the incoming CloudTrail from the Dev accounts.

After this is set up, we simply need to enable CloudTrail and send logs to the respective accounts
log group (on the logging account).

