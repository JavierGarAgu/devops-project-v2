# Understanding CSRF

CSFR is used for make your session personal with a random token generated for that specific session

What happens if u dont use CSFR? lets see with a analogy:

You’re sitting in your car, engine running, ready to drive somewhere.
Since the engine is on and the doors are unlocked, the car is basically waiting for your commands (like a website waiting for your authenticated requests).

While you’re distracted checking your phone, a stranger walks up and says:
"Hey, can you roll down the window for me? I dropped something outside."

Without thinking much, you press the button to roll down the window.

But here’s the catch — the stranger sneaks into the driver’s seat while the engine is running and the door is unlocked.
Because the car’s engine is already on (your session is active), the car lets the stranger start driving away!

Anyone watching just sees your car moving

CSRF basically relies on the fact that you opened the door to your car and then left it open, allowing someone else to simply drive the car and pretend to be you.

The Car and the Remote Key (CSRF Token)
You’re sitting in your car, engine running, ready to drive.
But here’s the thing: your car only lets you drive if it senses your remote key is nearby.

The remote key sends a secret wireless code to the car constantly.
If the car doesn’t detect the remote key, it will not start or it will stop itself immediately if it’s already running.

Now, imagine the attacker tries to take over your car while the engine is on and the doors are unlocked.

They might try to press buttons, steer, or drive away — but if your remote key is not with them, the car simply ignores their commands or even shuts off.

Without the remote key’s secret wireless code, the car refuses to move.

Now with a real example:

If you are logged into your bank, and then go to a different website, e.g. "www.bad_guy_banking_attacker.com" it is possible that you may click a form on that site that makes a POST request transferring money out of your bank account to the bad guy's account. Because you've already logged in, the bank's server may authorize the transaction. Hopefully your bank's server has implemented CSRF protection. The bad guy will need to have a token issued by the bank, within his malicious form. He won't have that token - or he will have to guess correctly. However, when you legitimately access your bank's web page, all forms within that page will have the token. Hence when that form is submitted, the server can check the veracity of the token.

If that is confusing, just think of the doorman analogy. Perhaps I will return one day and add a diagram to make it clear, if reader demand warrants it.

Thanks to the user [BenKoshy from Stackoverflow](https://stackoverflow.com/a/48535903/20513887) for that briliant explanation

# CSRF Problem with Django

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

First, what is Origin?

Origin is part of the web security model. It refers to the protocol + domain + port where a web request comes from. Django’s CSRF protection verifies that requests come from trusted origins only, to prevent Cross-Site Request Forgery attacks.

It checks the Origin header in the HTTP request.

If the Origin does not match the host exactly or is not in Django trusted origins list, Django will reject the request as a possible CSRF attack.

Oficial documentation [https://docs.djangoproject.com/en/5.2/ref/settings/#std-setting-CSRF_TRUSTED_ORIGINS]

Summary for practical purposes:
Origin is scheme + host + port (e.g., http://127.0.0.1:8000)

Django requires the Origin to be either:

Exactly the same as the Host header (including port), or

In the list of CSRF_TRUSTED_ORIGINS (which must be the full origin including scheme and port).

This is why my Nginx port mismatch breaks CSRF, and minikube generates random ports so the CSRF was impossible to use, so, for local tests i will use a nodeport service, and for real use the loadbalancer service





