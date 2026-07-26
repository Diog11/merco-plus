# Merco Plus — Plateforme de gestion (Flutter + Firebase)

Ce projet réécrit la plateforme de gestion Merco Plus avec la même stack
technique que votre document *Plan de Lancement MVP NSOMI JIRE*
(Flutter pour le mobile + web, Firebase pour le backend), adaptée aux
besoins du garage définis dans le cahier des charges : clients &
véhicules, stock de pièces, devis & factures, ateliers & planning.

⚠️ **Ce code n'a pas été compilé ni testé dans l'environnement où il a
été généré** (pas de SDK Flutter ni d'accès réseau disponibles ici).
C'est un point de départ solide et structuré, à ouvrir et faire tourner
dans votre propre environnement de développement — il faut s'attendre
à corriger quelques détails à la première compilation, comme pour tout
projet remis par un développeur.

## Phase 1 — Nouveau design premium (2026)

Refonte complète de l'habillage visuel, sans toucher à Firebase/Firestore
(vos données et votre configuration restent inchangées) :

- **Palette premium sombre** (fournie par vous : noir #0B0F19, gris
  #171C28, bleu #3B82F6, vert #22C55E, orange #F59E0B, rouge #EF4444),
  avec une **bascule sombre/clair** fonctionnelle dans le header
  (`lib/theme/app_theme.dart`).
- **Sidebar verticale rétractable** (`lib/widgets/mp_sidebar.dart`) —
  toujours sombre par choix de design (comme Linear/Vercel/Notion),
  quel que soit le thème choisi pour le reste de l'app.
- **Header moderne** (`lib/widgets/mp_header.dart`) : recherche,
  notifications avec badge de comptage réel (stock bas + factures
  impayées), menu "Créer" rapide, avatar (initiales), bascule thème.
- **Tableau de bord repensé** : bannière de bienvenue avec CA du mois et
  progression, cartes stats avec icônes, **graphique d'évolution du CA**
  (6 derniers mois, via `fl_chart`), **fil d'activité récente**, section
  **alertes** (stock bas, factures impayées, véhicules prêts), galerie
  photo.
- **Cartes avec glassmorphism léger** (`lib/widgets/animated_card.dart`) :
  apparition en fondu, effet de flou/transparence en mode sombre,
  soulèvement au survol.
- Icônes **Lucide** partout (`lucide_icons_flutter`).

⚠️ **Nouvelles dépendances** : après avoir remplacé le dossier du projet,
pensez à relancer `flutter pub get` avant `flutter run -d chrome`.

⚠️ **Si `flutter run` signale qu'une icône Lucide précise n'existe pas**
(ex. `LucideIcons.xxx isn't defined`) : c'est un nom d'icône à corriger,
rien de plus — dites-le-moi avec le nom exact de l'erreur et je corrige
immédiatement. Référence complète des icônes : https://lucide.dev/icons.

**Ce qui n'est pas encore fait** (prochaines phases, à faire module par
module comme convenu) : Véhicules en fiche détaillée séparée,
Fournisseurs, Paiements, Rapports avec export, Calendrier, Employés,
Diagnostics OBD, Kanban en glisser-déposer, codes-barres/QR,
envoi WhatsApp/e-mail des factures.

## Nouveau : connexion, inscription, navbar, animations

- Écran de **connexion** (`lib/screens/login_screen.dart`) et d'**inscription**
  (`lib/screens/signup_screen.dart`) via Firebase Authentication
  (e-mail / mot de passe). `lib/screens/auth_gate.dart` affiche
  automatiquement l'un ou l'autre selon que quelqu'un est connecté.
- **Navbar horizontale** en haut de l'écran sur desktop
  (`lib/widgets/mp_navbar.dart`), avec menu déroulant (Drawer) sur mobile.
- **Footer** en bas du tableau de bord (`lib/widgets/mp_footer.dart`).
- **Cartes animées** (`lib/widgets/animated_card.dart`) : légère apparition
  en fondu à l'ouverture + effet de "soulèvement" au survol de la souris.
- **Galerie photo** de l'atelier sur le tableau de bord, avec zoom léger
  au survol (mêmes photos libres de droits que la version web, à
  remplacer par vos propres photos dès que possible).

⚠️ **Étape supplémentaire à faire dans Firebase avant que connexion et
inscription fonctionnent** :
1. Console Firebase → votre projet `merco-plus` → **Authentication**
2. Onglet **"Sign-in method"** → **"Email/Password"** → l'activer
   (bouton à cocher, puis Enregistrer)

Sans cette étape, l'inscription/connexion renverra une erreur du type
*"la connexion par e-mail/mot de passe n'est pas encore activée"*.

## Phase 1.3 — Refonte complète (inspirée de Nsomi Jire)

Remise à plat de l'identité visuelle, pas une simple retouche cette fois :

- **Fond noir pur** (`#000000`) partout, cartes **sans aucune bordure**
  — elles se distinguent uniquement par une nuance de noir légèrement
  plus claire (`#0D0F11`) et une ombre portée.
- **Une seule couleur d'accent : le vert** (`#22C55E`), utilisée pour
  tous les boutons, liens actifs, icônes, badges. Le rouge/l'orange ne
  servent plus qu'à de vraies alertes fonctionnelles (facture impayée,
  stock bas) — jamais comme couleur décorative.
- **Hero du tableau de bord** entièrement repensé : beaucoup plus
  spacieux, avec le chiffre d'affaires du mois en très grand, le
  montant mis en avant en vert (façon "un mot en couleur" du hero
  Nsomi Jire), au lieu d'une petite carte encadrée sur le côté.
- **Correction du bug d'affichage** ("BOTTOM OVERFLOWED") de la navbar :
  hauteur et espacements des boutons ajustés pour ne plus déborder.
- Badge "MP" simplifié en aplat vert (au lieu du dégradé chromé).

Fichiers principalement concernés : `lib/theme/app_theme.dart`,
`lib/widgets/animated_card.dart`, `lib/widgets/kpi_card.dart`,
`lib/widgets/mp_top_nav.dart`, `lib/widgets/mp_badge.dart`,
`lib/screens/dashboard_screen.dart`.

## Phase 1.2 — Navbar horizontale, plus de couleur, carrousel

Suite à ton retour, nouveaux ajustements :

- **Navbar horizontale en haut** (`lib/widgets/mp_top_nav.dart`), qui
  remplace la sidebar verticale : logo, liens de navigation, recherche,
  notifications, "Créer", avatar, bascule thème — tout sur une seule
  ligne, avec un filet dégradé bleu → rouge en signature visuelle.
  L'ancien fichier `mp_sidebar.dart` ne garde que la petite classe
  `MpNavEntry` (utilisée par la navbar) ; `mp_header.dart` a été retiré.
- **Plus de couleur** : boutons "Créer" en dégradé bleu, liens actifs de
  la navbar en pastille bleue, petite barre d'accent colorée en haut de
  chaque carte KPI (bleu ou rouge selon le type de statistique).
- **Carrousel glissant** (`lib/widgets/mp_carousel.dart`) pour la galerie
  "Notre atelier en images" : cartes qui défilent au glisser-déposer,
  avec flèches et indicateurs à points, effet de zoom/fondu sur la
  carte active. Réutilisable pour d'autres sections à l'avenir (ex. mettre
  en avant plusieurs infos ou images sur une même carte).

## Phase 1 — Redesign premium (façon Stripe / Linear / Vercel)

Fondation visuelle entièrement refaite, appliquée à toute l'application :

- **Nouvelle palette sombre premium** (`lib/theme/app_theme.dart`) : noir
  #0B0F19, gris #171C28, bleu #3B82F6, blanc cassé #F8FAFC, vert #22C55E,
  orange #F59E0B, rouge #EF4444 — conforme à la charte fournie. Un thème
  clair cohérent existe aussi, activable via le bouton soleil/lune du
  header (persiste pendant la session).
- **Sidebar verticale rétractable** (`lib/widgets/mp_sidebar.dart`),
  toujours sombre, avec icônes Lucide — se réduit en mode "icônes
  seules" via le bouton en bas.
- **Header moderne** (`lib/widgets/mp_header.dart`) : recherche,
  notifications (badge avec le nombre d'alertes réelles), menu "Créer"
  rapide, avatar (initiales de l'utilisateur), bascule thème.
- **Cartes** (`lib/widgets/animated_card.dart`) : coins arrondis 18px,
  ombres légères, effet glassmorphism (flou) en mode sombre, apparition
  en fondu + léger survol.
- **Dashboard premium** (`lib/screens/dashboard_screen.dart`) :
  - Hero avec salutation dynamique (Bonjour/Bonsoir), CA du mois et
    évolution vs mois dernier
  - Graphique d'évolution du CA sur 6 mois (`fl_chart`), calculé à
    partir de vos factures réelles
  - Fil d'activité récente (devis/factures + interventions)
  - Section Alertes (stock en rupture, factures impayées, véhicules
    prêts) calculée en direct depuis Firestore

⚠️ Nouvelles dépendances ajoutées à `pubspec.yaml` (`lucide_icons_flutter`,
`fl_chart`) : pensez à relancer `flutter pub get` avant de relancer
l'application.

**Périmètre non couvert par cette Phase 1** (prévu pour les phases
suivantes, à discuter un module à la fois) : Véhicules en fiche séparée,
Fournisseurs, Paiements, Rapports avec export, Calendrier, Employés,
Diagnostics OBD, code-barres/QR, Kanban glisser-déposer, envoi
WhatsApp/e-mail des factures. Les 5 modules existants (Clients, Stock,
Devis/Factures, Ateliers) profitent déjà du nouveau thème et des
nouvelles cartes, mais gardent leur mise en page actuelle en attendant
leur tour.

## Ce qui est déjà en place

- Architecture en 5 écrans, calquée sur la version web : Tableau de
  bord, Clients & véhicules, Stock pièces, Devis & factures, Ateliers
  & planning.
- Modèles de données (`lib/models/models.dart`) et service Firestore
  (`lib/services/firestore_service.dart`) avec flux temps réel
  (`Stream`) pour chaque collection.
- Thème visuel repris de la version web (anthracite / chrome / bleu
  acier, typographies Oswald + Inter via `google_fonts`).
- Bannière vidéo d'arrière-plan sur le tableau de bord, avec une vidéo
  libre de droits (licence Pexels) en attendant vos propres images
  d'atelier.
- Règles Firestore de base (`firestore.rules`), à affiner avec de
  l'authentification par rôle.

## Mise en route

1. **Installer Flutter** (si ce n'est pas déjà fait) :
   https://docs.flutter.dev/get-started/install

2. **Récupérer les dépendances** :
   ```bash
   flutter pub get
   ```

3. **Créer un projet Firebase** sur https://console.firebase.google.com,
   puis activer :
   - Firestore Database (mode production)
   - Authentication (si vous voulez des comptes par rôle dès le départ)

4. **Générer la configuration Firebase réelle** (remplace le
   placeholder `lib/firebase_options.dart`) :
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

5. **Déployer les règles Firestore** :
   ```bash
   firebase deploy --only firestore:rules
   ```

6. **Lancer l'application** :
   ```bash
   flutter run -d chrome      # version web
   flutter run                # sur un appareil/émulateur mobile connecté
   ```

## Vos propres photos et vidéo

La bannière du tableau de bord (`lib/screens/dashboard_screen.dart`,
constante `_heroVideoUrl`) pointe vers une vidéo libre de droits
hébergée par Pexels. Dès que vous aurez une vidéo (ou des photos)
authentiques de votre atelier en bonne résolution :

1. Placez le fichier dans `assets/videos/atelier_bg.mp4`.
2. Déclarez-le dans `pubspec.yaml` (section `flutter: assets:`).
3. Remplacez `VideoPlayerController.networkUrl(...)` par
   `VideoPlayerController.asset('assets/videos/atelier_bg.mp4')`.

## Ce qui reste à faire (au-delà du prototype)

- Authentification et droits d'accès par rôle (gérant, réceptionniste,
  technicien, magasinier, comptable — cahier des charges §4.2).
- Génération de PDF pour les devis/factures (ex. package `pdf` +
  `printing`).
- Mode hors-ligne robuste (Firestore le permet nativement en activant
  la persistance locale — voir la doc `cloud_firestore`).
- Export/sauvegarde et tableau de bord de reporting plus poussé.
