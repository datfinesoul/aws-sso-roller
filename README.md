# aws_sso_roller

## Usage

```bash
# specifying the env variables disabled the prompts
SSO_START_URL='https://<yourorg>.awsapps.com/start' \
  SSO_REGION='<region>' \
  NAMESPACE='<short_prefix>' \
  ./aws-sso-roller.bash
```

### Example

If run with the following options:

```bash
SSO_START_URL='https://testorg.awsapps.com/start'
SSO_REGION='us-east-1'
NAMESPACE='xyz'
```

The output in the config file for each matching account/role would be:

```config
[profile xyz-accountname-NameOfRole]
sso_start_url = https://testorg.awsapps.com/start
sso_region = us-east-1
sso_role_name = NameOfRole
sso_account_id = 000000000000
```

Testing it you would then run:

```bash
export AWS_PROFILE='xyz-accountname-NameOfRole'
aws sso login
aws sts get-caller-identity
```

## Config Dir

- The generated client configuration files are stored in `${HOME}/.aws_sso_roller`.
- In addition, cached files (for `DEBUG='on'` mode) would also be stored there.

## Notes

```bash
SSO_START_URL='https://u-io.awsapps.com/start' \
  SSO_REGION='ap-northeast-1' \
  NAMESPACE='io' \
  ./aws-sso-roller.bash
```
