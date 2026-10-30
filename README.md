# Plateforme DevOps

TP1 : un cluster Kubernetes local et ArgoCD, gérés par Terraform.

## Prérequis

Docker doit être démarré. Les commandes se lancent dans Ubuntu / WSL2, avec
Terraform et kubectl installés dans Linux. Le dépôt doit rester dans `~/devops`,
pas dans `/mnt/c/`.

## Créer la plateforme

```bash
cd infra
terraform init
terraform plan -var-file=plateforme.tfvars
terraform apply -var-file=plateforme.tfvars
```

`plateforme.tfvars` contient le nom `plateforme` et la version `10.10.3` du
chart ArgoCD. Ce fichier ne contient aucun secret et est versionné.

Le module `cluster` crée le cluster kind et expose les informations de connexion.
Le provider Helm utilise ces sorties pour se connecter au cluster. Le module
`argocd` installe la release `argocd` dans le namespace du même nom.

Les contraintes des providers sont dans `infra/versions.tf`. Leurs versions
exactes et empreintes sont enregistrées dans `.terraform.lock.hcl`.

## Vérifier

```bash
kubectl --context kind-plateforme get nodes
kubectl --context kind-plateforme -n argocd get pods
kubectl --context kind-plateforme -n argocd get deploy argocd-server
terraform state list
terraform plan -var-file=plateforme.tfvars
```

Après application, le dernier plan ne doit proposer aucun changement.

## Accéder à ArgoCD

```bash
kubectl --context kind-plateforme -n argocd port-forward svc/argocd-server 8443:443
```

L'interface est accessible sur `https://localhost:8443`, avec le compte `admin`.
Le certificat local est autosigné. Pour lire le mot de passe initial dans son
propre terminal :

```bash
kubectl --context kind-plateforme -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Ne pas copier ce mot de passe dans le dépôt. Aucune application n'est encore
configurée dans ArgoCD à la fin du TP1.

## Détruire et reconstruire

Depuis `infra/` :

```bash
terraform destroy -var-file=plateforme.tfvars
terraform apply -var-file=plateforme.tfvars
```

Ces commandes détruisent puis recréent le cluster local du TP. Le state et le
fichier d'accès au cluster sont exclus de Git : les conserver localement.

## Organisation

```text
infra/
  main.tf                 appels des deux modules
  providers.tf            connexion de Helm au cluster
  versions.tf             contraintes de versions
  variables.tf            paramètres du projet
  plateforme.tfvars       valeurs utilisées pour le TP
  moved.tf                migration des adresses Terraform vers les modules
  modules/
    cluster/              cluster kind et sorties de connexion
    argocd/               installation du chart ArgoCD
app/                      application fournie pour les prochains TP
deploy/                   manifests des prochains TP
```

Les blocs `moved` conservent les ressources existantes lors du passage aux
modules. Ils n'empêchent pas un `destroy` explicite ni une création depuis zéro.
