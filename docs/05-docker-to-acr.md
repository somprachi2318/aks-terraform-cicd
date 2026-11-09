# Docker Image to Azure Container Registry

This tutorial describes how the project image is prepared for Azure Container Registry (ACR). The commands and project values below are included for reference; they were not run while writing this document.

## Why upload a Docker image to ACR?

The Docker image on a developer's computer is local to that computer. AKS needs to retrieve the image from a registry that it can reach when it starts the application. ACR stores the image in Azure so authorized users and services can pull it.

The general flow is:

1. Build the image locally.
2. Confirm that the image is present on the computer.
3. Sign in to ACR.
4. Tag the image with the ACR login server.
5. Push the tagged image to ACR.
6. Configure AKS access and refer to the image from a workload.

This project has not yet added an AKS cluster or configured AKS permissions to pull from ACR.

## 1. Check the local Docker image

The local image used for this project is `aks-flask-app:v1`. To check that Docker has it, list local images:

```powershell
docker images
```

Look for `aks-flask-app` with the `v1` tag. The image must already exist locally before it can be tagged and pushed. If it is missing, build it from the project root:

```powershell
docker build -t aks-flask-app:v1 ./app
```

## 2. Sign in to ACR

The project's registry is named `akscicd1p54c`. Sign in with Azure CLI:

```powershell
az acr login --name akscicd1p54c
```

This asks Azure CLI to authenticate Docker to the registry using your Azure sign-in. The registry's admin account is disabled, so use an authorized Azure identity; do not enable or share admin credentials to work around an access denial.

## 3. Tag the local image for ACR

Docker tags identify an image. Add the registry's login server to the local image name:

```powershell
docker tag aks-flask-app:v1 akscicd1p54c.azurecr.io/aks-flask-app:v1
```

This does not rebuild or upload the image. It adds another name to the same local image, now including the registry destination, repository name, and tag.

## 4. Push the image

Upload the tagged image to ACR:

```powershell
docker push akscicd1p54c.azurecr.io/aks-flask-app:v1
```

Docker sends the image's layers and associated metadata to the registry. After a successful push, Azure Portal can show the repository and tag.

## 5. Verify the repository and tag in Azure Portal

1. Open the [Azure Portal](https://portal.azure.com/) and sign in.
2. Open the Container Registry named `akscicd1p54c`.
3. Go to **Repositories**.
4. Open the `aks-flask-app` repository.
5. Check that the `v1` tag is listed.

This is the project verification path described here. The steps do not claim a new push was performed while writing this documentation.

## Image terms

### Docker image

An image is the packaged application and its dependencies. The local project image is named `aks-flask-app:v1`.

### Repository

A repository is a named collection of related images in a registry. Here, the repository is `aks-flask-app`.

### Tag

A tag is a human-friendly name that points to an image version in a repository. Here, `v1` is the tag.

Tags can be moved to point to a different image later. For an exact, immutable reference, use the image digest.

### Digest

A digest is a content-based cryptographic identifier for an image or manifest, usually shown with a `sha256:` prefix. If the content changes, its digest changes. This makes a digest a precise reference to the stored content.

### Image manifest

An image manifest describes one image for a particular platform. It lists the image's configuration and layer contents by digest.

### Image index

An image index (also called a manifest list) points to multiple platform-specific image manifests. A client such as a container runtime can select the right platform variant, for example Linux on amd64 or arm64, from the index.

### Attestation manifest

An attestation manifest stores related information about an image, such as build provenance or software-supply-chain metadata. It describes evidence about the image rather than acting as an additional runnable application image.

## Why might one tag show three manifests?

A registry can show more than one manifest associated with a tag because modern image publishing tools can publish a multi-platform image index plus related metadata, such as an attestation manifest. The index may point to a platform-specific image manifest, while an attestation records build information. These are different manifest objects, not necessarily three separately built application versions.

The exact objects depend on how the image was built and pushed. To confirm what is in this project's registry, inspect the remote image metadata rather than assuming every tag has the same structure.

## Inspect image metadata

Docker Buildx can inspect the remote image reference:

```powershell
docker buildx imagetools inspect akscicd1p54c.azurecr.io/aks-flask-app:v1
```

The output can show the image index or manifest media type, platform-specific manifests, and digests. If an index is listed, use the manifest details to see which platforms it covers. Output varies depending on the image and how it was published.

## Common authentication and permission errors

### Azure CLI is not signed in

If ACR login reports that the account is not signed in, authenticate with Azure CLI and check the active account:

```powershell
az login
az account show
```

Then retry `az acr login` for the registry.

### Wrong subscription or tenant

If the registry cannot be found, confirm Azure CLI is using the correct signed-in account and subscription. The registry name in this project is `akscicd1p54c`; do not include `.azurecr.io` in the `az acr login --name` argument.

### Permission denied during login or push

The identity may not have permission for the requested registry operation. Ask an administrator to check the identity's assigned ACR permissions and scope. The Terraform configuration disables the admin user and does not create role assignments. Do not put credentials in the repository or enable the admin user as a shortcut.

### Docker says the image or tag does not exist

Check the local image list with `docker images`, and verify the tag command used the exact local image and remote name. Tagging must succeed before pushing.

### Push is denied or fails midway

Confirm the Azure CLI session is valid, `az acr login` succeeded, the identity has push permission, and the registry login server is spelled correctly. Network interruptions can also require retrying the push.

## Interview questions

### 1. Why push an image to ACR before AKS uses it?

**Answer:** The local image exists only on the developer's computer. ACR stores it in Azure so authorized AKS workloads can retrieve it.

### 2. What does an image tag do?

**Answer:** A tag is a convenient name, such as `v1`, that points to an image in a repository. It can change, so a digest is more precise.

### 3. What is the difference between a repository and a tag?

**Answer:** A repository groups images under a name, such as `aks-flask-app`; a tag identifies a particular named version, such as `v1`.

### 4. What is an image digest?

**Answer:** A digest is a content-based identifier for image data or a manifest. It identifies exact content more reliably than a movable tag.

### 5. Why can a tag be associated with an image index and other manifests?

**Answer:** A multi-platform image may use an index to point to platform-specific images. Publishing tools may also attach an attestation manifest with build-related information.
