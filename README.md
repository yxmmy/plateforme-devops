# Plateforme DevOps

TP1 à TP4 : un cluster Kubernetes local et ArgoCD gérés par Terraform,
une API déployée par GitOps, une image publiée par GitHub Actions et un secret
chiffré dans Git avec Sealed Secrets.

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
`argocd` installe la release `argocd` dans le namespace du même nom et,
depuis le TP2, l’application racine qui lit le dépôt Git.

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

Ne pas copier ce mot de passe dans le dépôt. À la fin du TP1, aucune application n’était encore configurée dans ArgoCD.
Le TP2 ajoute les applications `racine`, `api-dev` et `api-prod`.

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

## Validation du TP1

Vérifications effectuées le 30 octobre 2026 :

- `terraform fmt -check -recursive` et `terraform validate` réussissent.
- La destruction puis reconstruction recrée les deux ressources Terraform.
- Le nœud Kubernetes est `Ready` et `argocd-server` est disponible (`1/1`).
- L'interface ArgoCD répond en HTTP par un port-forward temporaire.
- Un nouveau `terraform plan -var-file=plateforme.tfvars` indique `No changes`.

Versions résolues : provider kind `0.13.0`, provider Helm `3.3.0`, chart ArgoCD
`10.10.3`, Kubernetes `v1.37.0`. Le fichier de verrouillage fixe les providers.

## TP2 : déploiement GitOps

L'application `racine`, installée par Terraform avec le chart `argocd-apps`
`2.0.6`, surveille `deploy/argocd/` sur la branche `main` du dépôt public.
Elle crée les applications `api-dev` et `api-prod`, qui lisent leurs overlays.
Les trois applications utilisent la synchronisation automatique, `prune` et
`selfHeal`.

La base contient un Deployment et un Service `api`, sans namespace imposé.
Les overlays fixent le namespace et le tag d'image : un replica en `dev`, deux
en `prod`. Le Service expose le port 80 vers le port nommé `http` (8080) des pods.
La readiness probe utilise `/healthz`.

### Image locale

Depuis la racine du dépôt, une fois le cluster créé :

```bash
docker build -t api:initial app
kind load docker-image api:initial --name plateforme
```

Au TP2, cette image n’était pas encore publiée dans une registry. Après une
destruction du cluster, il fallait la recharger. Depuis le TP3, les overlays
utilisent une image publique GHCR, téléchargée automatiquement par les nœuds. `imagePullPolicy: IfNotPresent` permet aux
pods d'utiliser l'image chargée dans les nœuds kind.

### Vérifier les environnements

```bash
kubectl kustomize deploy/overlays/dev
kubectl kustomize deploy/overlays/prod
kubectl --context kind-plateforme -n argocd get applications
kubectl --context kind-plateforme -n dev get deploy,svc,pods
kubectl --context kind-plateforme -n prod get deploy,svc,pods
kubectl --context kind-plateforme -n dev port-forward svc/api 8080:80
```

Dans un autre terminal, `curl localhost:8080/` renvoie le nom du service,
la version et la présence ou non du jeton. `jeton_present: false` est normal
avant le TP sur les secrets.

### Modifier le déploiement

Modifier l'overlay, vérifier le résultat avec `kubectl kustomize`, puis commiter
et pousser. ArgoCD consulte périodiquement Git et applique le nouvel état.
Un changement manuel dans le cluster est corrigé par `selfHeal` : il ne remplace
pas une modification du dépôt.

Le TP2 a été vérifié en passant temporairement prod à trois replicas par Git,
puis en rétablissant les deux replicas attendus. Les tests de correction du
scaling manuel et de recréation du Deployment dev ont été réalisés séparément.

Le 30 octobre 2026, les trois applications étaient `Synced` et `Healthy`.
La correction du scaling manuel a pris environ 2,4 s ; le Deployment dev
a été recréé avec un nouvel UID et un pod disponible en environ 2,3 s.

## TP3 : du commit au cluster

Le workflow `.github/workflows/pipeline.yml` se déclenche sur un push dans
`main` uniquement si des fichiers sous `app/` ont changé.

1. Le pipeline calcule un tag avec les huit premiers caractères du commit.
2. Il construit l’image en passant ce tag comme argument `VERSION`.
3. Il publie l’image dans `ghcr.io/yxmmy/plateforme-devops`.
4. Il met à jour l’overlay dev avec `kustomize edit set image` et pousse un
   commit dont l’auteur est `pipeline-ci`.
5. ArgoCD lit ce commit et déploie la nouvelle image. Le pipeline ne possède
   aucun accès au cluster.

Les permissions `contents: write` et `packages: write` servent respectivement
au commit du tag et à la publication de l’image. L’authentification utilise le
`GITHUB_TOKEN` temporaire fourni par GitHub Actions ; aucun secret personnel
n’est ajouté au dépôt.

Les exécutions sont sérialisées pour éviter que deux pipelines modifient
l’overlay en même temps. Une relance qui trouve déjà le bon tag n’essaie pas
de créer un commit vide.

### Promotion en prod

La promotion consiste à recopier `newName` et `newTag` de l’overlay dev dans
l’overlay prod, puis à commiter et pousser. Les deux replicas prod utilisent
alors la même image validée en dev. Le pipeline ne promeut pas automatiquement.

Après une exécution du pipeline, faire un `git pull --ff-only` avant de
retravailler : le pipeline a ajouté un commit sur `main`.

### Validation effectuée le 30 octobre 2026

- Le [premier pipeline](https://github.com/yxmmy/plateforme-devops/actions/runs/41047495835)
  s’est terminé avec succès.
- L’image `ghcr.io/yxmmy/plateforme-devops:00079854` est accessible sans identifiant.
- Le commit automatique `a57c2bd` a été créé par `pipeline-ci`.
- L’API de dev a répondu avec `service: api-plateforme` et `version: 00079854`.
- Le commit de promotion `538ad96` a déployé cette même version sur les deux
  replicas prod.
- Les applications `racine`, `api-dev` et `api-prod` sont `Synced` et `Healthy`.
- Le commit du pipeline n’a pas déclenché un deuxième pipeline : il ne modifie
  que `deploy/`, exclu par le filtre `app/**`. Les pushes faits avec le
  `GITHUB_TOKEN` ne redéclenchent pas non plus les workflows de push.

Les images GHCR remplacent le chargement manuel de `api:initial` dans le cluster.

## TP4 : un secret chiffré dans Git

`deploy/argocd/sealed-secrets.yaml` confie à ArgoCD l’installation du chart
`sealed-secrets` `2.20.0` (contrôleur `0.40.0`). Le contrôleur est nommé
`sealed-secrets-controller` dans `kube-system`, comme le client `kubeseal`
l’attend.

`deploy/overlays/dev/api-secret-scelle.yaml` contient un `SealedSecret` nommé
`api-secret`, scellé pour le namespace `dev`. Seul ce fichier chiffré est
versionné. Le contrôleur le déchiffre et crée le `Secret` dans le cluster.

Le Deployment utilise `envFrom.secretRef` pour fournir la variable `JETON`
au conteneur. La référence est optionnelle : le même Deployment fonctionne
en prod, où aucun secret n’est encore configuré.

### Vérifier

```bash
kubectl --context kind-plateforme -n argocd get applications
kubectl --context kind-plateforme -n dev get sealedsecret api-secret
kubectl --context kind-plateforme -n dev get secret api-secret -o name
kubectl --context kind-plateforme -n dev port-forward svc/api 8080:80
```

`curl localhost:8080/` doit afficher `jeton_present: true` en dev. L’API
n’affiche jamais la valeur du jeton. En prod, la valeur attendue reste `false`.

### Après une reconstruction du cluster

La suppression du cluster supprime aussi la clé privée du contrôleur. Sans
restauration de cette clé, l’ancien fichier chiffré n’est plus déchiffrable.
Pour ce jeton de démonstration, générer une nouvelle valeur et la resceller,
une fois le contrôleur disponible, depuis la racine du dépôt :

```bash
python3 -c 'import secrets; print(secrets.token_urlsafe(32), end="")' \
  | kubectl create secret generic api-secret --namespace dev \
      --from-file=JETON=/dev/stdin --dry-run=client -o json \
  | kubeseal --context kind-plateforme \
      --controller-name sealed-secrets-controller \
      --controller-namespace kube-system --format yaml \
  > deploy/overlays/dev/api-secret-scelle.yaml
```

Cette commande renouvelle le jeton de démonstration sans l’afficher ni
l’enregistrer en clair dans un fichier. Valider le fichier avec
`kubeseal --context kind-plateforme --validate < deploy/overlays/dev/api-secret-scelle.yaml`,
puis commiter et pousser le fichier scellé. Une variable d’environnement est
lue au démarrage du pod : après renouvellement d’un secret existant, les pods
doivent redémarrer pour utiliser la nouvelle valeur.

### Validation effectuée le 30 octobre 2026

- Installation du contrôleur par ArgoCD, sans `helm install` manuel.
- Validation cryptographique du fichier avec `kubeseal --validate`.
- Secret créé avec un propriétaire de type `SealedSecret` et condition
  `Synced=True` sur la ressource scellée.
- Valeur brute et encodage base64 du jeton absents des fichiers candidats et
  des objets de l’historique Git avant publication.
- Réponse de dev : `jeton_present: true` ; réponse de prod : `false`.
- Un replica disponible en dev, deux en prod ; les quatre applications
  ArgoCD sont `Synced` et `Healthy`.

Le jeton a été créé uniquement en mémoire. Aucune clé privée du contrôleur
n’a été exportée et aucun `Secret` Kubernetes en clair n’a été versionné.
