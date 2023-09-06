# Terraform for Titan

There are 3 network environment(`goerli-nightly`, `goerli`, `mainnet`) to be operated by Terraform.
You can create, modify, delete them. And you can create the other environment.

### Prerequisite

- Terraform ([install doc](https://developer.hashicorp.com/terraform/downloads))
- AWS Route53 resource for `parents_domain` in `*.tfvars`

### Operate exist network environment

First, you have to set your AWS configure. profile name is in `environment/...` for each netork.

For example, in case of goerli-nightly, you have to set your aws profile name to `dev`. Or, you can change the `profile` variable in the `environment/goerli-nightly.tfvars` to your origin aws profile name.

```
# environment/goerli-nightly.tfvars

profile         = "dev" # you must change it in your local file ~/.aws/config
...

```

Next, run a script to create or update resources

```
./install.sh goerli-nightly
```

In case of deletions, run a script to delete resources

```
./delete.sh goerli-nightly
```

### Operate new network environment

First, you have to make a new workspace and select workspace for the new network environment.

```
terraform workspace new my_example_workspace
```

Next, make `my_example_workspace.tfvars` file in the `environment/` and edit the file refer to exist `*.tfvars` file.

```
cd environment
touch my_example_workspace.tfvars

# edit, my_example_workspace.tfvars
```

Run a terraform command to create or update resources

```
terraform init
terraform apply -var-file ./environment/my_example_workspace.tfvars -auto-approve
```

Run a terraform command to delete resources

```
terraform apply -var-file ./environment/my_example_workspace.tfvars -auto-approve -destroy
```
