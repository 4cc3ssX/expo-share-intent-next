# Direct Share with expo-share-intent

This example shows how to use the Direct Share feature on Android using the `expo-share-intent` module.

## Example Usage

```tsx
import React, { useState, useEffect } from 'react';
import { View, Text, Button, Image, StyleSheet, FlatList } from 'react-native';
import { useShareIntentContext } from 'expo-share-intent';

export default function MessagingScreen() {
  const [contacts, setContacts] = useState([
    { id: '1', name: 'John Doe', avatar: 'https://example.com/avatar1.jpg', lastMessage: 'Hey, how are you?' },
    { id: '2', name: 'Jane Smith', avatar: 'https://example.com/avatar2.jpg', lastMessage: 'Did you see the news?' },
    { id: '3', name: 'Mike Johnson', avatar: null, lastMessage: 'Let\'s meet tomorrow' },
  ]);
  
  const { donateSendMessage } = useShareIntentContext();
  
  // Register your top contacts as Direct Share targets
  useEffect(() => {
    // Register your most frequently contacted people as Direct Share targets
    contacts.forEach(contact => {
      donateSendMessage({
        conversationId: contact.id,
        name: contact.name,
        imageURL: contact.avatar,
        content: contact.lastMessage,
      });
    });
    
    // You can also update these targets when conversations change
    // For example, after sending or receiving a new message:
    const onNewMessage = (contact, message) => {
      donateSendMessage({
        conversationId: contact.id,
        name: contact.name,
        imageURL: contact.avatar,
        content: message,
      });
    };
    
    // Clean up would happen here
    return () => {
      // Any necessary cleanup
    };
  }, [contacts, donateSendMessage]);
  
  // Rest of your component...
  
  return (
    <View style={styles.container}>
      <Text style={styles.header}>Conversations</Text>
      <FlatList
        data={contacts}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={styles.contactItem}>
            {item.avatar ? (
              <Image source={{ uri: item.avatar }} style={styles.avatar} />
            ) : (
              <View style={styles.avatarPlaceholder}>
                <Text style={styles.avatarLetter}>{item.name[0]}</Text>
              </View>
            )}
            <View style={styles.contactDetails}>
              <Text style={styles.name}>{item.name}</Text>
              <Text style={styles.message}>{item.lastMessage}</Text>
            </View>
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
  },
  header: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 16,
  },
  contactItem: {
    flexDirection: 'row',
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
    alignItems: 'center',
  },
  avatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
  },
  avatarPlaceholder: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: '#3498db',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarLetter: {
    color: 'white',
    fontSize: 20,
    fontWeight: 'bold',
  },
  contactDetails: {
    marginLeft: 12,
    flex: 1,
  },
  name: {
    fontSize: 18,
    fontWeight: '500',
  },
  message: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
});
```

## Important Notes

### On Android
Direct Share targets will appear in the Android Sharesheet when users share content from other apps, allowing them to share directly to specific contacts in your app. The targets are also shown when long-pressing your app icon.

### Best Practices
1. Only add your most active/relevant contacts as Direct Share targets
2. Update the targets when new messages are sent or received to improve ranking
3. Remove stale contacts (no activity in 30+ days)
4. Make sure your shortcut IDs (conversationId) are consistent and unique
5. Always set the shortcut as long-lived with setLongLived(true) [already done in the native implementation]

### Limitations
- Android has a limit on how many dynamic shortcuts you can publish, so prioritize your most active conversations.
