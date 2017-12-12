## Concourse pipeline

Deployment:

```bash
fly -t cloudops set-pipeline -p divx-terraform-modules -c ./.ci/pipeline.yml
fly -t cloudops unpause-pipeline -p divx-terraform-modules
```

Destroy:

```bash
fly -t cloudops destroy-pipeline -p divx-terraform-modules
```

Expose:

```bash
fly -t cloudops expose-pipeline --pipeline divx-terraform-modules
# Revert with: fly -t cloudops hide-pipeline --pipeline divx-terraform-modules
```

### Required secrets

- Access token for setting status on PR's.
- Deploy key for pulling the repository.
