
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
helm install controller actions-runner-controller/actions-runner-controller --namespace actions-runner-system --create-namespace
helm uninstall controller --namespace actions-runner-system

kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_token=ghp_xxxYOURTOKENxxx

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

kubectl delete -f runner.yaml -n actions-runner-system
kubectl apply -f arc.yaml

logs

$pod = kubectl get pods -n actions-runner-system --no-headers |
       Where-Object {$_ -match "^custom-runner"} |
       ForEach-Object {($_ -split "\s+")[0]} |
       Select-Object -First 1

kubectl logs $pod -n actions-runner-system -c runner
kubectl describe pod $pod -n actions-runner-system

https://dev.to/ashokan/kubernetes-hosted-runners-for-github-actions-with-arc-g8a
https://medium.com/simform-engineering/how-to-setup-self-hosted-github-action-runner-on-kubernetes-c8825ccbb63c
https://actions-runner-controller.github.io/actions-runner-controller/

Install Custom Resource Definitions  (RunnerDeployment)

summerwind/actions-runner:latest is the default image for runner, so, to bake a custom image its a good practice to do it similar than the default image

The runner Dockerfiles can be found here: https://github.com/actions/actions-runner-controller/tree/master/runner and based on the Digest of the tags this is the actual latest: https://github.com/actions/actions-runner-controller/blob/master/runner/actions-runner.ubuntu-20.04.dockerfile


