import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_base_xr = {
    apiVersion = "hops.ops.com.ai/v1alpha1"
    kind = "GitopsEnvironment"
    metadata = {
        name = "staging"
        namespace = "production"
    }
    spec = {
        providerConfigRefs = {
            github = {
                name = "github"
                kind = "ProviderConfig"
            }
            kubernetes = {
                name = "production"
                kind = "ProviderConfig"
            }
        }
        namespace = {
            name = "staging"
            labels = {
                "gitkb.com/environment" = "staging"
            }
        }
        repository = {
            owner = "gitkb"
            name = "gitkb-staging-env"
            externalName = "gitkb-staging-env"
        }
        application.name = "gitkb-environment-staging"
    }
}

items = [
    metav1alpha1.CompositionTest {
        metadata.name = "imports-existing-environment-with-safe-ownership"
        spec = {
            compositionPath = "apis/gitopsenvironments/composition.yaml"
            xrdPath = "apis/gitopsenvironments/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata = {
                        name = "gitkb-staging-env"
                        annotations = {
                            "crossplane.io/external-name" = "gitkb-staging-env"
                        }
                    }
                    spec = {
                        managementPolicies = ["Observe", "Create", "Update", "LateInitialize"]
                        forProvider = {
                            name = "gitkb-staging-env"
                            visibility = "private"
                        }
                        providerConfigRef = {
                            name = "github"
                            kind = "ProviderConfig"
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "staging-namespace"
                    spec = {
                        managementPolicies = ["Observe", "Create", "Update", "LateInitialize"]
                        forProvider.manifest = {
                            apiVersion = "v1"
                            kind = "Namespace"
                            metadata = {
                                name = "staging"
                                labels = {
                                    "gitkb.com/environment" = "staging"
                                }
                            }
                        }
                        providerConfigRef = {
                            name = "production"
                            kind = "ProviderConfig"
                        }
                    }
                }
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "RepositoryWebhook"
                    metadata.name = "gitkb-staging-env"
                    spec = {
                        forProvider = {
                            events = ["push"]
                            repositoryRef.name = "gitkb-staging-env"
                            configuration = [{
                                contentType = "json"
                                insecureSsl = False
                                urlSecretRef = {
                                    name = "gitops-github-webhook"
                                    key = "url"
                                }
                                secretSecretRef = {
                                    name = "gitops-github-webhook"
                                    key = "secret"
                                }
                            }]
                        }
                        providerConfigRef = {
                            name = "github"
                            kind = "ProviderConfig"
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "staging-application"
                    spec = {
                        forProvider.manifest = {
                            apiVersion = "argoproj.io/v1alpha1"
                            kind = "Application"
                            metadata = {
                                name = "gitkb-environment-staging"
                                namespace = "argocd"
                            }
                            spec = {
                                project = "default"
                                source = {
                                    repoURL = "https://github.com/gitkb/gitkb-staging-env.git"
                                    targetRevision = "main"
                                    path = ".gitops/deploy/helm"
                                }
                                destination = {
                                    server = "https://kubernetes.default.svc"
                                    namespace = "argocd"
                                }
                            }
                        }
                        providerConfigRef = {
                            name = "production"
                            kind = "ProviderConfig"
                        }
                    }
                }
            ]
        }
    }

    metav1alpha1.CompositionTest {
        metadata.name = "creates-repository-from-template-with-explicit-deletion"
        spec = {
            compositionPath = "apis/gitopsenvironments/composition.yaml"
            xrdPath = "apis/gitopsenvironments/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = _base_xr | {
                metadata.name = "development"
                spec.namespace = {
                    name = "development"
                    allowDelete = True
                }
                spec.repository = {
                    owner = "gitkb"
                    name = "gitkb-development-env"
                    allowDelete = True
                    template = {
                        owner = "hops-ops"
                        repository = "gitops-template"
                    }
                }
                spec.application = {
                    name = "gitkb-environment-development"
                    project = "workloads"
                }
            }
            assertResources = [
                {
                    apiVersion = "repo.github.m.upbound.io/v1alpha1"
                    kind = "Repository"
                    metadata.name = "gitkb-development-env"
                    spec = {
                        managementPolicies = ["*"]
                        initProvider = {
                            deleteBranchOnMerge = True
                            template = [{
                                owner = "hops-ops"
                                repository = "gitops-template"
                                includeAllBranches = False
                            }]
                        }
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "development-namespace"
                    spec.managementPolicies = ["*"]
                    spec.forProvider.manifest.metadata.name = "development"
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "development-application"
                    spec.forProvider.manifest = {
                        metadata.name = "gitkb-environment-development"
                        spec.project = "workloads"
                    }
                }
            ]
        }
    }
]
