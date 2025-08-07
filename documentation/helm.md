
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
  LC_COLLATE = 'es_ES.UTF8'
  LC_CTYPE = 'es_ES.UTF8';


psql -h host -U postgres -d final_project -f .\init.sql

#manual delete database if will it needed
DROP DATABASE final_project;

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