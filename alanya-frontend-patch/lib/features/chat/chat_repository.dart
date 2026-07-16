import '../../core/authed_api.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';

class ChatRepository {
  ChatRepository(this._api);

  final AuthedApi _api;

  /// Liste des conversations (paginée).
  /// ✅ NOUVEAU : Retourne { conversations: [...], nextCursor }
  Future<ConversationListResult> listConversations({int limit = 50, String? cursor}) async {
    String path = '/api/conversations?limit=$limit';
    if (cursor != null) path += '&cursor=$cursor';
    
    final data = await _api.get(path);
    
    final conversations = ((data['conversations'] as List?) ?? [])
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
    
    return ConversationListResult(
      conversations: conversations,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  /// Crée (ou récupère) une conversation directe avec un utilisateur via son UUID.
  /// ✅ NOUVEAU : Le backend attend participantIds (UUID), pas publicNumber.
  /// Il faut d'abord résoudre le publicNumber → userId via /api/users/public/:number
  Future<String> createDirect(String targetUserId) async {
    final data = await _api.post('/api/conversations', {
      'isGroup': false,
      'participantIds': [targetUserId],
    });
    return data['id'] as String;
  }

  /// Crée une conversation de groupe.
  /// ✅ NOUVEAU : participantIds au lieu de memberNumbers
  Future<String> createGroup(String name, List<String> participantIds) async {
    final data = await _api.post('/api/conversations', {
      'isGroup': true,
      'name': name,
      'participantIds': participantIds,
    });
    return data['id'] as String;
  }

  /// Détail d'une conversation.
  Future<Conversation> getConversation(String conversationId) async {
    final data = await _api.get('/api/conversations/$conversationId');
    return Conversation.fromJson(data);
  }

  /// Met à jour une conversation (nom, avatar - admin seulement).
  Future<Conversation> updateConversation(String conversationId, {
    String? name,
    String? avatarUrl,
  }) async {
    final data = await _api.put('/api/conversations/$conversationId', {
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return Conversation.fromJson(data);
  }

  /// Ajoute des participants à un groupe (admin seulement).
  Future<List<dynamic>> addParticipants(String conversationId, List<String> participantIds) async {
    return _api.post('/api/conversations/$conversationId/participants', {
      'participantIds': participantIds,
    });
  }

  /// Retire un participant (ou quitte soi-même).
  Future<void> removeParticipant(String conversationId, String targetUserId) async {
    await _api.delete('/api/conversations/$conversationId/participants/$targetUserId');
  }

  /// Quitte la conversation.
  Future<void> leaveConversation(String conversationId) async {
    await _api.post('/api/conversations/$conversationId/leave', {});
  }

  /// Messages paginés d'une conversation.
  /// ✅ NOUVEAU : Retourne { messages: [...], nextCursor }
  Future<MessageListResult> getMessages(
    String conversationId, {
    int limit = 50,
    String? cursor,
    String? before,
  }) async {
    String path = '/api/conversations/$conversationId/messages?limit=$limit';
    if (cursor != null) path += '&cursor=$cursor';
    if (before != null) path += '&before=$before';
    
    final data = await _api.get(path);
    
    final messages = ((data['messages'] as List?) ?? [])
        .map((m) => Message.fromJson(m as Map<String, dynamic>))
        .toList();
    
    return MessageListResult(
      messages: messages,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  /// Envoie un message texte.
  Future<Message> sendText(String conversationId, String content, {String? replyToId}) async {
    final data = await _api.post('/api/conversations/$conversationId/messages', {
      'content': content,
      'type': 'text',
      if (replyToId != null) 'replyToId': replyToId,
    });
    return Message.fromJson(data);
  }

  /// Envoie un message média.
  Future<Message> sendMedia(String conversationId, String mediaId, String type, {String? replyToId}) async {
    final data = await _api.post('/api/conversations/$conversationId/messages', {
      'type': type,
      'mediaId': mediaId,
      if (replyToId != null) 'replyToId': replyToId,
    });
    return Message.fromJson(data);
  }

  /// Marque un message comme lu.
  /// ✅ NOUVEAU : PUT sur /messages/{messageId}/read (pas POST sur /conversations/{id}/read)
  Future<void> markMessageRead(String conversationId, String messageId) async {
    await _api.put('/api/conversations/$conversationId/messages/$messageId/read', {});
  }

  /// Supprime un message (expéditeur seulement).
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _api.delete('/api/conversations/$conversationId/messages/$messageId');
  }

  /// Masque un message pour soi-même (soft delete).
  /// ✅ NOUVEAU : POST /hide au lieu de DELETE ?scope=me
  Future<void> hideMessage(String conversationId, String messageId) async {
    await _api.post('/api/conversations/$conversationId/messages/$messageId/hide', {});
  }

  /// Transfère un message vers une ou plusieurs conversations.
  /// ❌ N'existe pas encore dans le backend NestJS - à implémenter ou retirer
  Future<void> forwardMessage(String conversationId, String messageId, List<String> targetConvIds) async {
    // TODO: Backend endpoint manquant
    throw UnimplementedError('Forward message not yet implemented in NestJS backend');
  }

  /// Nombre de messages non lus.
  Future<int> getUnreadCount(String conversationId) async {
    final data = await _api.get('/api/conversations/$conversationId/messages/unread/count');
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }
}

/// Résultat paginé pour les conversations.
class ConversationListResult {
  final List<Conversation> conversations;
  final String? nextCursor;

  ConversationListResult({required this.conversations, this.nextCursor});
}

/// Résultat paginé pour les messages.
class MessageListResult {
  final List<Message> messages;
  final String? nextCursor;

  MessageListResult({required this.messages, this.nextCursor});
}