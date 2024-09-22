We specify a release name when we deploy a chat using `helm install`

Installing a release - `helm install -f values-override.yaml release-name bitnami/wordpress` it can be -f or --values to specify values file.

# Steps -

- Create a new helm chart using the command `helm create service-name`
- Update Chart.yaml to reflect the metadata about the service
- Update templates folder to add new services and then update values.yaml (or dev.values.yaml like)
- Test with `helm lint my-microservice` and `helm template my-microservice --debug`
- Create a release with the release name. 


# Destroy 

Use helm uninstall command 


# Test the template values 

`helm install --debug --dry-run release-name ./chart-folder`

# Helm namespace 

When installing we can also specify a namespace. This is a kubernetes namespace where helm chart files will be stored. 

Example - `helm install release-name ./chart-folder-name --namespace dev`. 

With this we can make sure that we install the same chart multiple times in different namespaces. 

We also need to make sure the namespaces of deployments are also in different namespaces. 