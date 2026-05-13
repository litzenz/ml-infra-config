### k3d init
```sh
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
# create cluster with port mapping: client:8080 to loadbalancer:80
k3d cluster create mlops --agents 1 -p "8080:80@loadbalancer"
```

### argocd-cli
```sh
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd
```

### argocd
```sh
kubectl create namespace argocd
# server-side for server side apply with large manifest 
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# make sure argocd is listening on 80 (http)
kubectl apply -f argocd-cm-insecure.yaml
kubectl rollout restart deployment argocd-server -n argocd

# traefik route to service argocd-server:80
kubectl apply -f argocd-ingress.yaml
echo 127.0.0.1 argocd.localhost >> \etc\hosts

argocd admin initial-password -n argocd
argocd login argocd.localhost:8080 --username admin --insecure --plaintext --grpc-web
```

### app test
from path of repo with deployment+svc.yaml, chart.yaml (helm) or kustomization.yaml
```sh
argocd app create guestbook \
--repo https://github.com/argoproj/argocd-example-apps.git \
--path guestbook \
--dest-server https://kubernetes.default.svc \
--dest-namespace default

argocd app list

argocd app sync guestbook

argocd app delete guestbook --cascade
```
![port forwarding](./port_fw.png)

### gitea (local git)
```sh
kubectl create namespace gitea
kubectl apply -f mlops-config/infrastructure/gitea/gitea-app.yaml 
kubectl apply -f mlops-config/infrastructure/gitea/gitea-ingress.yaml 

echo 127.0.0.1 gitea-http.gitea.svc.cluster.local >> \etc\hosts

argocd repo add http://gitea.k3d.localhost/admin/ml-infra-config.git --username admin --password <your-password>
```

### ml infra config
create argocd manifest repo to start: 

```sh
kubectl apply -f ml-infra-config/bootstrap/argocd-projects.yaml # track projects folder for project
kubectl get appprojects -n argocd

kubectl apply -f ml-infra-config/bootstrap/infra-apps.yaml # track infrastructure folder for infra tools

# project based app deployment
kubectl apply -f ml-infra-config/bootstrap/default-apps.yaml # track services/default-project
```

### kserve
https://github.com/kserve/kserve.git/charts:
- crds
- resources
- runtimes: --set kserve.servingruntime.enabled=true 

### kserve inference service
Inside the cluster, other pods can reach this service at:
[http://sklearn-iris-predictor.default.svc.cluster.local]()

`svc/sklearn-iris-predictor-default` is the full identifier for the service object in your cluster:
- svc/: This tells kubectl you are looking for a Service resource.
- sklearn-iris: The name you gave your isvc in metadata.name.
- predictor: The component of the isvc (KServe can also have transformer or explainer components).
- default: ~~The namespace where the service lives.~~ (no need in kserve raw deployment)

Portforward:
```sh
# kubectl port-forward svc/<service-name> <local-port>:<service-port>
kubectl port-forward svc/sklearn-iris-predictor 8081:80 -n default
```

Endpoint: KServe expects a specific URL (**Open Inference Protocol**) path to handle the prediction request: 
`/v2/models/sklearn-iris/infer`

Then use [http://localhost:8081/v2/models/sklearn-iris/infer]() to hit the model
```sh
curl -v http://localhost:8081/v2/models/sklearn-iris/infer \
-H "Content-Type: application/json" \
-d @- <<EOF
{
  "inputs": [
    {
      "name": "input-0",
      "shape": [2, 4],
      "datatype": "FP32",
      "data": [
        [6.8, 2.8, 4.8, 1.4],
        [6.0, 3.4, 4.5, 1.6]
      ]
    }
  ]
}
EOF
```

### todo
- terraform for argocd
- argocd manifest for kserve + promethues + grafana
- kserve custom runtimes
- split ml-infra-config and ml-apps-config into 2 repos


