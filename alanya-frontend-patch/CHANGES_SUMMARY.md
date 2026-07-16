# Résumé des modifications - Frontend Flutter → Backend NestJS

## 📋 Vue d'ensemble

Ce patch adapte le frontend Flutter (alanya) pour fonctionner avec le nouveau backend NestJS.
Les changements principaux concernent : **format de réponse**, **endpoints REST**, **flow media**, **WebSocket**.

---

## 🔴 Fichiers modifiés (Core)

### 1. `lib/core/api_client.dart`
- **Ajout** : Méthode `put()` pour les endpoints RESTful
- **Modification majeure** : `_decode()` déballé maintenant l'enveloppe NestJS `{ data: ..., timestamp: ... }`
- Toutes les réponses API retournent maintenant directement le contenu de `data`

### 2. `lib/core/authed_api.dart`
- **Ajout** : Support de la méthode `put()`
- **Refresh token** : Déjà compatible (utilise `_api.post` qui déballé `data`)

### 3. `lib/core/server_config.dart`
- **URLs mises à jour** : 
  - API : `http://localhost:3000/api` (dev) / `https://api.alanya.app/api` (prod)
  - WebSocket : `http://localhost:3000` (dev) / `wss://api.alanya.app` (prod)
- **Note** : Le `/api` prefix est maintenant inclus dans `apiBase`

### 4. `lib/core/socket_service.dart` **(NOUVEAU)**
- Remplace l'ancien WebSocket natif par `socket_io_client`
- Compatible avec le `EventsGateway` NestJS (Socket.io)
- Événements supportés : messages, typing, appels, statuts, présence
- Mutex de reconnexion, auto-reconnect, authentification par token JWT

---

## 🟡 Fichiers modifiés (Features)

### 5. `lib/features/auth/auth_repository.dart`
| Ancien | Nouveau |
|--------|---------|
| `register({email})` | `register({email, password, idPays?, nom?})` |
| `login({identifier, password})` | `login({email, password})` - **identifier → email** |
| `me()` → `/api/me` | `me()` → `/api/users/me` |
| `logout()` | `logout(refreshToken)` + `resendVerification()` |

### 6. `lib/features/chat/chat_repository.dart`
| Ancien | Nouveau |
|--------|---------|
| `listConversations()` | Retourne `ConversationListResult` avec `nextCursor` |
| `createDirect(publicNumber)` | `createDirect(targetUserId)` - **UUID requis** |
| `createGroup(name, memberNumbers)` | `createGroup(name, participantIds)` - **UUIDs requis** |
| `markRead(convId)` → `POST /conversations/{id}/read` | `markMessageRead(convId, msgId)` → `PUT /messages/{id}/read` |
| `deleteMessage(scope=me)` → `DELETE ?scope=me` | `hideMessage()` → `POST /messages/{id}/hide` |
| `forwardMessage()` | ❌ **Non implémenté côté backend** |

### 7. `lib/features/contacts/contacts_repository.dart`
| Ancien | Nouveau |
|--------|---------|
| `searchByNumber(number)` | `searchByQuery(q)` - **paramètre `q` au lieu de `number`** |
| `matchNumbers()` | **Simulé** par appels séquentiels à `searchByQuery()` |
| `list()` | Retourne directement `List<Contact>` (pas enveloppé) |
| `setBlocked()` → `PATCH` | `setBlocked()` → `PUT` |
| `unregister(token)` | `unregister(deviceId)` + helper `unregisterByToken()` |

### 8. `lib/features/account/account_repository.dart`
| Ancien | Nouveau |
|--------|---------|
| `updateProfile()` → `PATCH /api/account/profile` | `updateProfile()` → `PUT /api/users/me` |
| `getProfile()` → `/api/me` | `getProfile()` → `/api/users/me` |
| **Nouveau** | `getByPublicNumber()`, `searchUsers()` |

### 9. `lib/features/media/media_repository.dart`
**Changement majeur : Flow upload en 3 étapes**
```
1. getPresignedUploadUrl()  → POST /api/media/presign-upload
   → Retourne { mediaId, uploadUrl, method, headers, key, provider }
   
2. uploadDirect()           → PUT/POST direct vers uploadUrl (S3/B2/local)
   → Upload binaire SANS passer par le backend
   
3. confirmUpload()          → POST /api/media/confirm-upload
   → Retourne { id, url, mimeType, size, filename }
```

### 10. `lib/features/calls/calls_repository.dart`
| Ancien | Nouveau |
|--------|---------|
| `start(convId, type)` | `start(convId, type, targetUserId)` |
| `accept/reject/end/leave` | Unifié : `PUT /api/calls/action` avec `{callId, action}` |
| `sendSignal()` REST | **Via WebSocket** `call:signal` |
| `iceServers()` | ❌ Endpoint manquant (config par défaut fournie) |
| `history()` | Paginé avec `nextCursor` |

### 11. `lib/features/push/push_repository.dart`
| Ancien | Nouveau |
|--------|---------|
| `unregister(token)` → `DELETE /api/push/register?token=` | `unregister(deviceId)` → `DELETE /api/push/devices/{deviceId}` |
| **Nouveau** | `listDevices()` → `GET /api/push/devices` |

### 12. `lib/features/status/status_repository.dart`
| Ancien | Nouveau |
|--------|---------|
| `feed()` | Paginé avec `nextCursor` |
| `createText()` | `type: 'text'` + `backgroundColor` |
| `createMedia()` | `type: 'image'|'video'` + `mediaId` |
| **Nouveau** | `getUserStatuses()`, `getViews()` |

---

## 📦 Dépendances à ajouter dans `pubspec.yaml`

```yaml
dependencies:
  socket_io_client: ^2.0.0  # Pour le WebSocket Socket.io
  # http, http_parser déjà présents
```

---

## 🚀 Étapes d'application du patch

### 1. Appliquer les fichiers
```bash
# Dans votre repo alanya (frontend Flutter)
cp -r /path/to/alanya-frontend-patch/lib/* lib/
```

### 2. Ajouter la dépendance
```yaml
# pubspec.yaml
dependencies:
  socket_io_client: ^2.0.0
```

### 3. Installer
```bash
flutter pub get
```

### 4. Mettre à jour l'initialisation du Socket
Dans votre `main.dart` ou `bootstrap()` :
```dart
// Avant (ancien WebSocket)
final ws = WebSocketService();

// Après (Socket.io)
final socketService = SocketService.getInstance(tokenStorage);
await socketService.connect();
```

### 5. Configurer les URLs (build)
```bash
# Développement
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api --dart-define=WS_URL=http://10.0.2.2:3000

# Production
flutter build apk --dart-define=API_URL=https://api.alanya.app/api --dart-define=WS_URL=wss://api.alanya.app
```

---

## ⚠️ Points d'attention

### Résolution publicNumber → userId
Le backend NestJS utilise des **UUID** pour les relations. Le frontend doit :
1. Appeler `GET /api/users/public/:publicNumber` pour obtenir le `userId`
2. Utiliser ce `userId` pour `createDirect()`, `addParticipant()`, etc.

### Modèles Dart à mettre à jour
Les modèles (`AuthUser`, `Conversation`, `Message`, `Contact`, `Status`, `CallRecord`, etc.) doivent correspondre aux nouveaux schémas de réponse NestJS. Vérifiez les champs :
- `publicNumber` (String, 6 chiffres)
- `pseudo` (nullable)
- `isOnline` (int 0/1 → convertir en bool)
- Timestamps : `createdAt`, `updatedAt` en ISO 8601

### WebSocket - Changement de paradigme
| Ancien (ws://) | Nouveau (Socket.io) |
|----------------|---------------------|
| Connexion unique | Auto-reconnect + multiplexing |
| Ping/pong manuel | Heartbeat automatique |
| Événements custom | Namespaces + rooms (`conversation:{id}`) |
| Auth via query param | Auth via `auth: {token}` au handshake |

---

## ✅ Checklist de validation

- [ ] `flutter pub get` passe
- [ ] `flutter analyze` sans erreurs
- [ ] Inscription → OTP → Setup → Login fonctionne
- [ ] Liste conversations + messages temps réel
- [ ] Envoi message texte + média
- [ ] Appel audio/video (signalisation WebSocket)
- [ ] Statuts (création, vue, feed)
- [ ] Contacts (recherche, ajout, blocage)
- [ ] Profil (mise à jour pseudo/avatar/status)
- [ ] Push notifications (enregistrement device)
- [ ] Reconnexion WebSocket après coupure réseau

---

## 🆘 Support

Si vous rencontrez des problèmes :
1. Vérifiez les logs backend (NestJS + Prisma)
2. Vérifiez les logs Flutter (dio/http + socket_io_client)
3. Comparez les requêtes/réponses avec la doc Swagger : `http://localhost:3000/docs`