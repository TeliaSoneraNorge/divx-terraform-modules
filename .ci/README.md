## Concourse pipeline

Deployment:

```bash
fly -t prod-cloudops set-pipeline -p divx-terraform-modules -c ./.ci/pipeline.yml
fly -t prod-cloudops unpause-pipeline -p divx-terraform-modules
```

Destroy:

```bash
fly -t prod-cloudops destroy-pipeline -p divx-terraform-modules
```

Expose:

```bash
fly -t prod-cloudops expose-pipeline --pipeline divx-terraform-modules
# Revert with: fly -t prod-cloudops hide-pipeline --pipeline divx-terraform-modules
```

### Required secrets

- Access token for setting status on PR's.
- Deploy key for pulling the repository.
