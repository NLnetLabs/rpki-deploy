# To run Krill E2E tests locally

_(assumes that you have the necessary [pre-requisites installed](https://github.com/NLnetLabs/rpki-deploy/tree/master/terraform/krill-e2e-test#requirements))_

## One-time setup

**Note:** Does not work with latest Terraform, last tested with Terraform 0.12.19.

```
git clone https://github.com/NLnetLabs/rpki-deploy.git
cd rpki-deploy/terraform/krill-e2e-test/run_on_localhost
terraform init
```

At this point Terraform will complain that it cannot find at least one plugin as you need to install them locally like so:

```
cp ../../plugins/* ~/.terraform.d/plugins
terraform init
```

## Run

_(assumes that you have the Krill Git repository cloned somewhere locally)_

```
terraform apply -var krill_build_path=<path/to/your/krill/clone>
```
