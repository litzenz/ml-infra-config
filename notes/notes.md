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

### todo
- terraform
- kserve
- project+namespace management
- split ml-infra-config and ml-apps-config into 2 repos


