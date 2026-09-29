# hiveostemplate

HiveOS (dernière version) dans un conteneur Docker, pour les GPU loués (vast.ai…).
Même principe que l'image HiveOS de Clore.ai : tu renseignes `RIG_ID`, `RIG_PASSWD` et
`FARM_HASH`, le worker apparaît dans ton tableau de bord HiveOS, et tu pilotes le minage
avec tes Flight Sheets.

Image publiée : `clusmi/hiveostemplate:latest` (publique).

## Ce que fait l'image

- installe le paquet `hive` en **dernière version** depuis le dépôt officiel de Hiveon
  (`download.hiveos.farm`). Le dépôt est signé : l'empreinte de sa clé est vérifiée à la
  construction ;
- au démarrage : écrit la config du worker, se connecte à HiveOS, lance l'agent (le lien
  avec le tableau de bord), le mineur de ta Flight Sheet et le watchdog HiveOS ;
- affiche dans les logs du conteneur le journal de l'agent et la console du mineur.

**Seulement les cartes louées.** Dans un conteneur, HiveOS verrait toutes les cartes de la
machine hôte. Au démarrage, l'image repère les cartes réellement louées (celles que le pilote
NVIDIA montre au conteneur) et masque les autres : le tableau de bord n'affiche que tes GPU.

Les mineurs ne sont pas dans l'image : HiveOS les télécharge lui-même quand tu appliques
une Flight Sheet (mineurs intégrés et « custom miners »).

**Neutralisé, car impossible sur un GPU loué** (l'hôte garde la main sur le matériel) :

| Fonction HiveOS | Dans ce conteneur |
|---|---|
| Overclocking NVIDIA / AMD / Intel, tweakers | ignoré, avec un message dans le journal d'OC |
| Autofan (ventilateurs) | ignoré |
| Mise à jour du pilote NVIDIA | ignorée (le pilote vient de l'hôte) |
| Reboot depuis le tableau de bord | relance le mineur et l'agent |
| Shutdown depuis le tableau de bord | arrête le mineur |

## Mise en place (une seule fois)

1. **Docker Hub** : crée le dépôt `hiveostemplate` (public). Tu peux réutiliser le token
   *Read & Write* créé pour l'autre projet.
2. **GitHub** : crée un dépôt et envoie les fichiers **à la racine**, dossiers `.github` et
   `rootfs` compris (pas dans un sous-dossier).
3. Dans le dépôt GitHub : *Settings → Secrets and variables → Actions → New repository secret*
   - `DOCKERHUB_USERNAME` : ton identifiant Docker Hub (`clusmi`)
   - `DOCKERHUB_TOKEN` : ton token Docker Hub
4. Onglet **Actions** → *Construire et publier l'image* → **Run workflow**.

Pour passer à une nouvelle version de HiveOS, relance le workflow : il reprend toujours la
dernière version du dépôt officiel.

## Variables d'environnement

| Variable | Obligatoire | Rôle |
|---|---|---|
| `RIG_ID` | voir ci-dessous | identifiant du worker HiveOS |
| `RIG_PASSWD` | voir ci-dessous | mot de passe du worker |
| `FARM_HASH` | voir ci-dessous | hash de la ferme |
| `WORKER_NAME` | non | nom du worker créé avec `FARM_HASH` seul |
| `HIVE_HOST_URL` | non | serveur API HiveOS (défaut `http://api.hiveos.farm`) |

Il faut **`FARM_HASH`**, ou **`RIG_ID` + `RIG_PASSWD`**, ou les trois comme sur Clore :

- avec `RIG_ID` + `RIG_PASSWD`, le conteneur se rattache à un worker que tu as déjà créé ;
- avec `FARM_HASH` seul, HiveOS crée un nouveau worker au premier démarrage. Si l'instance
  redémarre, le conteneur réutilise ce worker au lieu d'en créer un autre.

Où trouver les valeurs dans HiveOS :
- **RIG_ID** et **RIG_PASSWD** : ouvre le worker, puis ses réglages (*Settings*) ;
  ils figurent aussi dans le `rig.conf` que HiveOS propose en téléchargement ;
- **FARM_HASH** : réglages de la ferme (*Farm → Settings → Hash*).

## Template vast.ai

- **Image Path:Tag** : `clusmi/hiveostemplate`, version `latest`
- **Launch mode** : **Docker ENTRYPOINT**
- **Champ des arguments** : **vide**
- **Environment Variables** : `RIG_ID`, `RIG_PASSWD`, `FARM_HASH`

Le premier démarrage sur une machine prend un peu plus de temps (image d'environ 300 Mo,
puis téléchargement du mineur par HiveOS).

## Sécurité : une ferme dédiée aux locations

Le propriétaire de la machine louée peut techniquement lire les variables de ton conteneur,
donc ton `FARM_HASH` et ton `RIG_PASSWD`. Avec le Farm Hash, on peut ajouter des workers à
ta ferme. Crée une **ferme HiveOS réservée aux locations**, séparée de tes vrais rigs.

## Dépannage

- **`HiveOS refuse les identifiants`** dans les logs : `RIG_ID`, `RIG_PASSWD` ou `FARM_HASH`
  incorrect (HiveOS répond par exemple `Worker not found`).
- **`impossible de joindre HiveOS`** : pas d'accès réseau depuis la machine louée, ou
  `HIVE_HOST_URL` erroné.
- **Le worker est en ligne mais ne mine pas** : aucune Flight Sheet appliquée, ou le mineur
  n'est pas encore téléchargé ; regarde la console du mineur dans les logs.
- **Toutes les cartes de l'hôte apparaissent, en « MALFUNCTION »** : image antérieure au
  filtre des cartes louées ; relance le workflow et recrée l'instance. La ligne
  `GPU : cartes louees : …` des logs indique les cartes retenues.
- **`No such container` sur vast.ai** : l'image n'a pas pu être téléchargée ; vérifie que le
  dépôt Docker Hub est public.
- **Ouvrir un shell** : `docker run --rm -it clusmi/hiveostemplate bash`

Les messages `libkmod`, `could not get list of modules` ou `modinfo … amdgpu` au démarrage
sont normaux dans un conteneur : HiveOS cherche des modules du noyau auxquels un conteneur
n'a pas accès.
