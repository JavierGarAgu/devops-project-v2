
### INSTALL Helm(admin rights)

Invoke-WebRequest https://raw.githubusercontent.com/asheroto/winget-installer/master/winget-install.ps1 -UseBasicParsing | iex

winget install Helm.Helm

### Install minikube for testing (admin rights)

[oficial documentation](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download)

New-Item -Path 'c:\' -Name 'minikube' -ItemType Directory -Force
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -OutFile 'c:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing

$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
if ($oldPath.Split(';') -inotcontains 'C:\minikube'){
  [Environment]::SetEnvironmentVariable('Path', $('{0};C:\minikube' -f $oldPath), [EnvironmentVariableTarget]::Machine)
}

minikube config set driver docker

minikube delete

minikube start

### force docker desktop restart

# Stop Docker Desktop
Stop-Process -Name "Docker Desktop" -Force

# Start Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"


### psql manual load sql (is in dam app project)

CREATE DATABASE final_project
  WITH TEMPLATE = template0
  ENCODING = 'UTF8'
  LC_COLLATE = 'en_US.UTF8'
  LC_CTYPE = 'en_US.UTF8';


psql -h host -U postgres -d final_project -f .\init.sql

#manual delete database if will it needed

DROP DATABASE final_project;

# create docker images into minikube

& minikube -p minikube docker-env | Invoke-Expression
docker build --no-cache -t myapp-django:1.0.0 .


# TODO fix

Prohibido (403)
La verificación CSRF ha fallado. Solicitud abortada.

Help
Reason given for failure:

    Origin checking failed - http://127.0.0.1:43686 does not match any trusted origins.
    
In general, this can occur when there is a genuine Cross Site Request Forgery, or when Django’s CSRF mechanism has not been used correctly. For POST forms, you need to ensure:

Your browser is accepting cookies.
The view function passes a request to the template’s render method.
In the template, there is a {% csrf_token %} template tag inside each POST form that targets an internal URL.
If you are not using CsrfViewMiddleware, then you must use csrf_protect on any views that use the csrf_token template tag, as well as those that accept the POST data.
The form has a valid CSRF token. After logging in in another browser tab or hitting the back button after a login, you may need to reload the page with the form, because the token is rotated after a login.
You’re seeing the help section of this page because you have DEBUG = True in your Django settings file. Change that to False, and only the initial error message will be displayed.

You can customize this page using the CSRF_FAILURE_VIEW setting.

SOLUTION

FIRST STOP ALL SERVICES USING PORT 80

netstat -aon | findstr :80
NET stop HTTP

then

kubectl port-forward service/nginx 80:80

If u prefer to use another port:

settings.py of the Django app
https://stackoverflow.com/questions/70508568/django-csrf-trusted-origins-not-working-as-expected/70518254
(last message)

# ARC

Actions Runner Controller (ARC) is a Kubernetes operator that orchestrates and scales self-hosted runners for GitHub Actions.

[Official repo](https://github.com/actions/actions-runner-controller)

Commands:

helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager --namespace cert-manager --set installCRDs=true

helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update
kubectl create namespace actions-runner-system

kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_token=ghp_xxxYOURTOKENxxx

helm install controller actions-runner-controller/actions-runner-controller --namespace actions-runner-system --create-namespace

helm uninstall controller --namespace actions-runner-system



arc.yaml

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: example-runnerdeploy
  namespace: actions-runner-system
spec:
  replicas: 1
  template:
    spec:
      repository: JavierGarAgu/devops-project-v2
```

kubectl delete -f arc.yaml -n actions-runner-system
kubectl apply -f arc.yaml

logs

$pod = kubectl get pods -n actions-runner-system --no-headers |
       Where-Object {$_ -match "^example-runnerdeploy-"} |
       ForEach-Object {($_ -split "\s+")[0]} |
       Select-Object -First 1

kubectl logs $pod -n actions-runner-system -c runner
kubectl describe pod $pod -n actions-runner-system

https://dev.to/ashokan/kubernetes-hosted-runners-for-github-actions-with-arc-g8a
https://medium.com/simform-engineering/how-to-setup-self-hosted-github-action-runner-on-kubernetes-c8825ccbb63c
https://actions-runner-controller.github.io/actions-runner-controller/
https://pkg.go.dev/github.com/actions-runner-controller/actions-runner-controller#section-readme


Install Custom Resource Definitions  (RunnerDeployment)

summerwind/actions-runner:latest is the default image for runner, so, to bake a custom image its a good practice to do it similar than the default image

The runner Dockerfiles can be found here: https://github.com/actions/actions-runner-controller/tree/master/runner and based on the Digest of the tags this is the actual latest: https://github.com/actions/actions-runner-controller/blob/master/runner/actions-runner.ubuntu-20.04.dockerfile

build the image:

& minikube -p minikube docker-env | Invoke-Expression
docker build --no-cache -t pruebas:latest --build-arg RUNNER_VERSION=2.319.1 --build-arg RUNNER_CONTAINER_HOOKS_VERSION=0.4.0 .


some documentation

https://stackoverflow.com/questions/75057349/how-to-apply-yaml-file-on-terraform
https://registry.terraform.io/providers/hashicorp/kubernetes/2.25.1/docs/resources/manifest
https://stackoverflow.com/questions/79128174/using-same-terraform-project-to-create-the-kubernetes-infrastructure-and-deploy

ACTUAL PROBLEMS:

The user alexsomesan from [this issue](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1775#issuecomment-1193859982) explained it perfectly; "The kubernetes_manifest resource needs access to the API server of the cluster during planning. This is because, in order to support CRDs in Terraform ecosystem, we need to pull the schema information for each manifest resource at runtime (during planing).

AFAICS, every person who reported seeing similar issues above, configures the attributes of the provider "kubernetes" {..} block using references to other resources' attributes. You can only do this if the referenced resource (the cluster in this case) IS ALREADY PRESENT before you start planing / applying any of the kubernetes_manifest resources. You can achieve this as simply as using the -target CLI argument to Terraform to limit the scope of the first apply to just the cluster and it's direct dependencies. Then you follow up with a second apply without a -target argument and this constructs the rest of the resources (manifest & others). You will end up with a single state file and subsequent updates no longer require this two-step approach as long as the cluster resource is present.

This limitation is stemming from Terraform itself, and the provider tries to push things as far as it can, but there is no way around needing access to schema from the API (Terraform is fundamentally a strongly-typed / schema based system)."

that explains everything of this error:

│ Error: Failed to construct REST client
│
│   with module.eks.kubernetes_manifest.cert_manager_crds["3"],
│   on modules\eks\main.tf line 95, in resource "kubernetes_manifest" "cert_manager_crds":
│   95: resource "kubernetes_manifest" "cert_manager_crds" {
│
│ cannot create REST client: no client config


So we have two options, or create the flow in two different steps, one for the creation of EKS cluster and another for the manifest or my actual option, use extern provider to supply a direct solution

KUBECTL_MANIFEST BY GAVINBUNNEY

https://github.com/gavinbunney/terraform-provider-kubectl
https://registry.terraform.io/providers/gavinbunney/kubectl/latest

To use external provider we need to include it in Terraform plugin folder on your system

https://github.com/gavinbunney/terraform-provider-kubectl/releases

CERT MANAGER MANAGE PROBLEMS

helm history cert-manager -n cert-manager
helm status cert-manager -n cert-manager
helm list -n cert-manager

kubectl get all -n cert-manager
kubectl get pods -n cert-manager -o wide
kubectl describe pod -n cert-manager cert-manager-58dd99f969-6p67b
kubectl describe pod -n cert-manager cert-manager-cainjector-55cd9f77b5-77vkq
kubectl describe pod -n cert-manager cert-manager-webhook-7987476d56-5nrp6

kubectl get nodes -o wide
kubectl describe node <your-node-name>
kubectl get events -A --sort-by=.metadata.creationTimestamp

ARC MANAGE PROBLEMS

kubectl describe pod -n actions-runner-system
kubectl get events -n actions-runner-system --sort-by=.metadata.creationTimestamp
kubectl logs -n actions-runner-system pod/controller-actions-runner-controller-b97b7d8bf-6ghf9 -c manager
helm list -n actions-runner-system
helm uninstall actions-runner-controller -n actions-runner-system
kubectl delete namespace actions-runner-system

AWS NODE GROUP PROBLEM BLOCK SOLUTION

aws autoscaling delete-auto-scaling-group --auto-scaling-group-name eks-my-private-eks-ng-72cc7b0a-a253-540f-489b-72ee3dc4ac7b --force-delete --region eu-north-1

aws ec2 delete-launch-template --launch-template-id lt-064ec842ccf46c0a7 --region eu-north-1

aws eks delete-nodegroup --cluster-name my-private-eks --nodegroup-name my-private-eks-ng --region eu-north-1

aws eks describe-nodegroup --cluster-name my-private-eks --nodegroup-name my-private-eks-ng --region eu-north-1

aws eks delete-cluster --name my-private-eks --region eu-north-1


Delete the autoscaling group for the node group and force delete it so it removes all instances.
Delete the EC2 launch template that was used by the node group.
Delete the EKS node group from the cluster.
Check the status of the EKS node group to make sure it is deleted or still deleting.
Finally, delete the EKS cluster itself.

https://medium.com/@opstimize.icarus/aws-eks-without-nat-gateway-5cbe577aa8ca

test this option

NodeCreationFailure
Your launched instances are unable to register with your Amazon EKS cluster. Common causes of this failure are insufficient node IAM role permissions or lack of outbound internet access for the nodes. Your nodes must meet either of the following requirements:

Able to access the internet using a public IP address. The security group associated to the subnet the node is in must allow the communication. For more information, see Subnet requirements and considerations and View Amazon EKS security group requirements for clusters.

Your nodes and VPC must meet the requirements in Deploy private clusters with limited internet access.

https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html#worker-node-fail

## Problem Summary

I created a runner in the `actions-runner-system` namespace using ARC. Later, I tried deleting the namespace, but it got stuck in `Terminating` because Kubernetes thought there was still a runner resource with finalizers. Even though the runner was deleted, the namespace finalizer reference remained, preventing the namespace from terminating.

### Key Issue
- `kubectl get ns` showed the namespace as `Terminating` for hours.
- Attempts to delete or patch the runner kept failing because the webhook service no longer existed.
- Standard `kubectl delete` or `helm uninstall` commands did not resolve the problem.

---

## Steps Taken to Resolve the Problem

### 1. Verify the stuck namespace
```powershell
kubectl get ns
```
Output:
```
actions-runner-system   Terminating   4h45m
```

### 2. Attempted deleting the runner
```powershell
kubectl delete runners --all -n actions-runner-system
```
Output:
```
runner.actions.summerwind.dev "example-runnerdeploy-9lnjr-2hhwk" deleted
```
> Even though the runner was deleted, the namespace stayed in `Terminating`.

### 3. Checked namespace finalizers
```powershell
kubectl get namespace actions-runner-system -o json
```
- Found `finalizers` blocking termination.
- Tried patching using `kubectl patch`, `kubectl replace`, and JSON modifications, but PowerShell encoding issues (BOM/UTF8) caused errors.

### 4. Exported the namespace JSON and cleaned encoding
```powershell
kubectl get namespace actions-runner-system -o json > ns.json
```
- Opened `ns.json` and made sure:
```json
"spec": {
  "finalizers": []
}
```
- Saved the file as UTF-8 **without BOM**.

### 5. Force finalize the namespace
```powershell
kubectl replace --raw "/api/v1/namespaces/actions-runner-system/finalize" -f ns.json
```
- This forced Kubernetes to remove the stale finalizer reference.

### 6. Verify the namespace deletion
```powershell
kubectl get ns
```
Output:
```
NAME              STATUS   AGE
cert-manager      Active   5h16m
default           Active   5h40m
kube-node-lease   Active   5h40m
kube-public       Active   5h40m
kube-system       Active   5h40m
```
> The `actions-runner-system` namespace is gone.

---

## Key Takeaways

- Kubernetes can leave namespaces stuck in `Terminating` if a resource with a finalizer has already been deleted.
- Standard delete/patch operations may fail if webhooks or controllers are no longer available.
- Force finalization using the `/finalize` endpoint is a reliable way to clean up stuck namespaces.
- PowerShell may add BOMs when writing files; Kubernetes requires UTF-8 without BOM for JSON.

---

## Summary of Commands Used

```powershell
# 1. Check namespace status
kubectl get ns

# 2. Delete all runners
kubectl delete runners --all -n actions-runner-system

# 3. Export namespace JSON
kubectl get namespace actions-runner-system -o json > ns.json

# 4. Edit ns.json and remove finalizers
# "spec": { "finalizers": [] }

# 5. Force finalize the namespace
kubectl replace --raw "/api/v1/namespaces/actions-runner-system/finalize" -f ns.json

# 6. Verify namespace deletion
kubectl get ns
```

This guide fully documents my process and solution.
