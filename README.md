# Blue-Green Deployment on Kubernetes

Two versions of a small Node.js service (blue and green) run side by side. One Service decides which version receives traffic, so a release is a single selector change and a rollback is the same change in reverse.

## 1. Problem Statement

XYZ Corporation needs releases with no downtime and an instant rollback. The task is to:

- run a Blue Deployment and a Green Deployment at the same time,
- switch traffic between them through a Service,
- keep each version on its own Git branch (`blue` and `green`),
- show that traffic moves to green and can move back to blue.

## 2. Repository Layout

    app/        Node.js service, Dockerfile, version.json (the only file that differs between versions)
    k8s/        namespace, deployment-blue, deployment-green, service (the traffic switch)
    scripts/    switch.sh (switch traffic), check.sh (send 10 requests, show who answered)
    evidence/   switch-test.log

**Branches:** `main` holds the shared tooling and the blue version. `blue` holds the blue release and `green` holds the green release. The two release branches differ only in `app/version.json`. Images are `kaj1/bluegreen-app:blue` and `kaj1/bluegreen-app:green`.

## 3. Steps to Build and Run

Prerequisites: a Kubernetes cluster (k3s), `kubectl`, Docker.

    # 1. Build and push each version from its own branch
    git checkout blue  && docker build -t kaj1/bluegreen-app:blue  app/ && docker push kaj1/bluegreen-app:blue
    git checkout green && docker build -t kaj1/bluegreen-app:green app/ && docker push kaj1/bluegreen-app:green
    git checkout main

    # 2. Deploy both versions and the Service
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/
    kubectl -n bluegreen get pods,svc --show-labels

    # 3. Check which version answers (Service starts on blue)
    ./scripts/check.sh

    # 4. Switch to green, then roll back
    ./scripts/switch.sh green && ./scripts/check.sh
    ./scripts/switch.sh blue  && ./scripts/check.sh

`switch.sh` waits for the target Deployment to be fully rolled out, patches the Service selector (`version: blue|green`), waits 3 seconds, then prints the selector it set.

## 4. Switch Test Result

Output from `evidence/switch-test.log` (10 requests per step):

| Step | Service selector | Answers received |
|---|---|---|
| Before | version: blue | 10 x blue |
| After switch | version: green | 10 x green |
| Rollback | version: blue | 10 x blue |

Both Deployments stay running (2 replicas each), so the idle version is ready for an instant rollback.

## 5. Optimization Techniques Used

- **One image, two tags:** the versions differ by a single file, so builds are small and fast.
- **Switch only after readiness:** `switch.sh` runs `rollout status` on the target first, so traffic never goes to pods that are not ready.
- **Readiness and liveness probes** on `/health`.
- **Instant rollback:** the old version stays deployed, so rolling back is one `patch`, not a redeploy.
- **Non-root, locked-down containers:** `runAsNonRoot`, `allowPrivilegeEscalation: false`, Alpine base image.
- **Resource requests and limits** on both Deployments.
- **No hard-coded port in the test:** `check.sh` reads the NodePort from the Service.

## 6. Challenges Faced and Solutions

| Challenge | Solution |
|---|---|
| The first test run looked successful but tested nothing. `kubectl apply` rejected the Service because NodePort 30090 was already used by another app on the cluster, and the check script still curled that port. | Moved the Service to NodePort 30191, made `check.sh` read the port from the Service, and made it print only the `version` field, so a response from the wrong app shows as `no-response`. |
| Right after switching back to blue, the check still got green answers, although the selector was already `blue`. | The selector changes instantly, but kube-proxy takes a moment to update its routing rules. `switch.sh` now waits 3 seconds after the patch. |
| The fixes had to reach all branches. | Committed on `main`, then merged `main` into `blue` and `green` so every branch has the same scripts and manifests. |
