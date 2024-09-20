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