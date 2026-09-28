# KFramework

**KFramework** est un framework RolePlay pour serveurs **FiveM**, écrit en **Lua** avec une partie interface (NUI) en **HTML/CSS/JS**.

Il fournit une base complète de gestion pour un serveur RP : personnages, items, jobs, gangs, et un système d'**exports** permettant à d'autres ressources d'interagir facilement avec le framework.

> ⚠️ Ce framework reprend le **core et les composants de base** du projet [flashlandv8_gamemode](https://github.com/pablo-1610/flashlandv8_gamemode), largement retravaillés et étendus depuis.

---

## ✨ Fonctionnalités

- **Gestion des personnages** — création, sélection, sauvegarde des données joueur
- **Gestion des items** — inventaire, poids, utilisation, métadonnées
- **Système de jobs** — grades, salaires, permissions par métier
- **Système de gangs** — hiérarchie, territoires (selon implémentation), gestion des membres
- **Système d'exports** — expose les fonctions clés du framework pour être consommées par des ressources tierces (voir [Exports](#exports))
- **Interface NUI** — écrans HTML/CSS/JS pour l'inventaire, les menus, etc.

---

## 🛠️ Stack technique

| Composant | Technologie |
|---|---|
| Serveur / Client | Lua (FiveM) |
| Interface (NUI) | HTML / CSS / JavaScript |
| Base de données | MySQL |

---

## 📦 Dépendances

**Aucune dépendance externe à installer.** Les briques nécessaires au fonctionnement du framework sont **directement intégrées** dans la resource :

- `Bob74` (intégré)
- `mysql-async` (intégré)

Il suffit donc de récupérer KFramework et de le lancer, sans avoir à installer d'autres ressources en parallèle.

---

## 🚀 Installation

1. Placer le dossier `KFramework` dans votre dossier `resources`.
2. Importer le fichier `schema.sql` (ou équivalent) dans votre base de données.
3. Ajouter dans votre `server.cfg` :

```cfg
set mysql_connection_string "mysql://USER:PASSWORD@HOST/DATABASE?charset=utf8mb4"

ensure KFramework
```

4. Adapter le fichier de configuration du framework (`config.lua` ou équivalent) selon vos besoins (jobs, gangs, items de base, etc.).

---

## 🔌 Exports

L'un des principaux apports de ce fork par rapport au core d'origine est la mise en place d'un **système d'exports**, permettant à n'importe quelle autre ressource FiveM d'interagir avec KFramework sans dépendance directe au code source.

Exemple d'utilisation depuis une autre ressource :

```lua
-- Récupérer les données d'un joueur
local playerData = exports['KFramework']:GetPlayerData(source)

-- Ajouter un item à un joueur
exports['KFramework']:AddItem(source, 'item_name', 1)

-- Vérifier le job d'un joueur
local job = exports['KFramework']:GetPlayerJob(source)
```

> ℹ️ Adaptez les noms de fonctions ci-dessus à ceux réellement exposés dans votre code (`server/exports.lua` ou équivalent).

---

## 📁 Structure du projet

```
KFramework/
├── client/
├── server/
├── nui/            # Interfaces HTML/CSS/JS
├── config/
├── schema.sql
├── fxmanifest.lua
└── README.md
```

*(à adapter selon l'arborescence réelle de votre resource)*

---

## Origine & Crédits

KFramework reprend le **core** et la **base des components** du projet **FlashLand V8 Gamemode**

Le projet d'origine a été publié en accès libre par ses auteurs sous licence **GPL-3.0**.

Depuis cette base, KFramework a été **significativement retravaillé**, notamment via l'ajout d'un **système d'exports** permettant l'interopérabilité avec d'autres ressources, absent du projet original.

---

## 📜 Licence

Ce projet est distribué sous licence **[GNU Affero General Public License v3.0 (AGPL-3.0)](https://www.gnu.org/licenses/agpl-3.0.html)**.

Points clés à retenir :

- Vous pouvez utiliser, modifier et redistribuer ce code librement.
- **Toute modification distribuée ou exploitée via un réseau (y compris un serveur FiveM public)** doit voir son code source rendu disponible aux utilisateurs qui interagissent avec, sous la même licence.
- Aucune garantie n'est fournie ("tel quel").

ℹ️ Le projet d'origine (flashlandv8_gamemode) étant sous **GPL-3.0**, et l'AGPL-3.0 étant explicitement conçue pour être compatible avec la GPL-3.0 (voir section 13 de l'AGPL), la republication de ce fork sous AGPL-3.0 est cohérente d'un point de vue licence.

---

## Avertissement

Ni les auteurs originaux de flashlandv8_gamemode, ni les mainteneurs de KFramework, ne sont responsables de l'usage qui sera fait de ce framework, ni des problèmes rencontrés lors de son utilisation.
