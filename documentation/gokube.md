First of all, what is gokube:

gokube is a package developed by Thales that automates all the process of download the stack for minikube (docker, kubectl, minikube itself, helm)

how to install:


https://github.com/thalesgroup/gokube/releases/tag/v1.36.0

place the .exe file into a directory, in my case i followed the recomendations of gokube official documentation

![](../documentation/gokube-images/1.png)


And to use it without the need of write the path, its recommended to add it into env variables path module

![](../documentation/gokube-images/2.png)

To test that it works

![](../documentation/gokube-images/3.png)

![](../documentation/gokube-images/4.png)

Because i had virtualbox and hyper-v, i decided to use only vb, so y disabled hyper-v bcdedit /set hypervisorlaunchtype off

$env:MINIKUBE_CPUS="2"
$env:MINIKUBE_MEMORY="6144"

i decided to use that requirement because with the default my pc will explode