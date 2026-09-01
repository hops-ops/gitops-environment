# gitops-environment

`GitopsEnvironment` registers one workload environment with GitHub, Kubernetes,
and Argo CD. It creates or imports the environment repository, ensures the
workload namespace exists, configures an authenticated GitHub webhook, and
creates the root Argo CD Application that syncs the repository.

## Why GitopsEnvironment?

Without this resource, every environment requires independently maintained
repository settings, Namespace YAML, webhook configuration, and an Argo CD
Application in the cluster bootstrap repository. Those copies drift and make
adding an environment a multi-system procedure.

With `GitopsEnvironment`, the environment identity is independent from its
repository name, existing repositories can be adopted without replacement,
and a cluster can register environments from one directory of XR manifests.

## The journey

### Stage 1: Import an existing environment

Set `repository.externalName` to adopt an existing GitHub repository. Imported
repositories cannot enable deletion. Namespace deletion is also disabled by
default, so removing an XR does not remove promoted workloads accidentally.

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: GitopsEnvironment
metadata:
  name: staging
  namespace: production
spec:
  providerConfigRefs:
    github:
      name: github
      kind: ProviderConfig
    kubernetes:
      name: production
      kind: ProviderConfig
  namespace:
    name: staging
  repository:
    owner: gitkb
    name: gitkb-staging-env
    externalName: gitkb-staging-env
  application:
    name: gitkb-environment-staging
```

The GitHub ProviderConfig owner must match `repository.owner`.

### Stage 2: Create from a template

Omit `externalName` and provide a template when a new environment should start
from an established repository layout.

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: GitopsEnvironment
metadata:
  name: development
  namespace: production
spec:
  namespace:
    name: development
  repository:
    owner: gitkb
    name: gitkb-development-env
    template:
      owner: hops-ops
      repository: gitops-template
```

Repository and Namespace deletion remain disabled unless their respective
`allowDelete` fields are explicitly set. `allowDelete` is rejected for an
imported repository.

For a shared preview repository that creates a namespace per pull request,
omit `spec.namespace`. The XR then owns the repository, webhook, and root
Application without creating an unused static Namespace.

### Stage 3: Customize synchronization

The default Application syncs `.gitops/deploy/helm` from `main` into `argocd`.
Override the Application fields when a repository uses another layout or Argo
CD project.

```yaml
spec:
  application:
    name: team-a-staging
    namespace: argocd
    project: team-a
    path: environments/staging
    targetRevision: main
    destination:
      server: https://kubernetes.default.svc
      namespace: argocd
```

### Stage 4: Reuse the cluster webhook secret

By default, the webhook reads `url` and `secret` from
`gitops-github-webhook` in the XR namespace. A cluster-level GitOps stack can
generate and rotate that shared secret while every environment gets its own
repository webhook.

```yaml
spec:
  webhook:
    enabled: true
    events:
      - push
    secretRef:
      name: gitops-github-webhook
      urlKey: url
      secretKey: secret
```

## Status

The XR publishes `status.namespace`, `status.repository.url`, and the
Application name and namespace under `status.application`.

## Composed resources

- `Repository` creates or imports the GitHub environment repository.
- `Object` creates the workload `Namespace` on the target cluster.
- `RepositoryWebhook` sends authenticated push events to Argo CD.
- `Object` creates the root Argo CD `Application`.

## Development

```shell
make render
make validate
make test
make build
```

## License

Apache-2.0
