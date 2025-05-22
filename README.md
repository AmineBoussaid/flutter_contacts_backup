# 📱 flutter_contacts_backup
> Application mobile.
> Objectif : Sauvegarder et restaurer les contacts, SMS et favoris d’un utilisateur sur Firebase.

---

## 🔍 Présentation

Cette application Flutter permet à un **utilisateur authentifié par Google** de :

- Sauvegarder ses **contacts**, **SMS** et **favoris** dans **Firebase**.
- Restaurer ses données à tout moment depuis le cloud.
- Gérer ses contacts et favoris localement grâce à une base SQLite.

Le projet est conçu pour fonctionner avec un smartphone Android ou un émulateur configuré avec des contacts/SMS simulés.

---

## ✨ Fonctionnalités principales

✅ Authentification via **compte Google**  
✅ Sauvegarde/restauration vers **Firebase Realtime Database**  
✅ Détection automatique des **modifications récentes** (par date)  
✅ Gestion locale des favoris avec **SQLite**  
✅ Visualisation claire des :

- 📇 **Contacts** (Nom, photo, date création, téléphone, email, favoris)
- 💬 **SMS** regroupés par contact (affichage du dernier, développement à la demande)
- ⭐ **Favoris** (Nombre d’appels et SMS, actions rapides : appel/SMS)

---


## 🛠️ Prérequis
- Flutter SDK

- Firebase CLI

- flutterfire_cli

- Un compte académique Google (pour Firebase)

## 🚀 Installation et Lancement

1. Cloner le projet
   - git clone https://github.com/TON-UTILISATEUR/contacts_app.git
   - cd contacts_app
2. Installer les dépendances
   - flutter pub get
3. Initialiser Firebase
   - flutterfire configure.
  🔒 Assure-toi d’avoir connecté ton compte Firebase, créé un projet, activé l’authentification Google et ajouté ton utilisateur de test.
4. Lancer l'application
   - flutter run

## 📦 Dépendances clés
 - firebase_core
 - firebase_auth
 - firebase_database
 - google_sign_in
 - sqflite
 - provider
 - flutterfire_cli

## 👨‍💻 Auteur
Projet Flutter développé par : Boussaid Amine & Farhan Mohammed
Programmation Mobile
