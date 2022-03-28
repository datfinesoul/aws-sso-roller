# aws_sso_roller

## Usage

```bash
# specifying the env variables disabled the prompts
SSO_START_URL='<profile_name>' \
  SSO_REGION='<region>' \
  NAMESPACE='<short_prefix>' \
  ./go.bash

# this is only required if the org changed or credentials expired
aws sso login # only neede
# test that you have access
aws --profile <profile_name> sts get-caller-identity
```

## Config Dir

- The generated client configuration files are stored in `${HOME}/.aws_sso_roller`.
- In addition, cached files (for `DEBUG='on'` mode) would also be stored there.

## Notes

```bash
SSO_START_URL='https://u-io.awsapps.com/start' \
  SSO_REGION='ap-northeast-1' \
  NAMESPACE='io' \
  ./go.bash
```
