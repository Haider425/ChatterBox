const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotification = functions.firestore
    .onDocumentCreated('chats/{chatId}/messages/{messageId}', async (event) => {
        try {
            const snapshot = event.data;
            const message = snapshot.data();
            const chatId = event.params.chatId;

            // Get chat document
            const chatDoc = await admin.firestore()
                .collection('chats')
                .doc(chatId)
                .get();

            if (!chatDoc.exists) {
                console.log('Chat document not found');
                return;
            }

            const chatData = chatDoc.data();
            const participants = chatData.participants;
            const senderId = message.senderId;

            // Get recipient ID
            const recipientId = participants.find(id => id !== senderId);
            if (!recipientId) {
                console.log('Recipient not found');
                return;
            }

            // Get recipient's FCM token
            const recipientDoc = await admin.firestore()
                .collection('users')
                .doc(recipientId)
                .get();

            if (!recipientDoc.exists) {
                console.log('Recipient document not found');
                return;
            }

            const recipientData = recipientDoc.data();
            const recipientToken = recipientData.fcmToken;

            if (!recipientToken) {
                console.log('No FCM token found for recipient: ${recipientId}');
                return;
            }

            // Get sender's name
            const senderDoc = await admin.firestore()
                .collection('users')
                .doc(senderId)
                .get();

            if (!senderDoc.exists) {
                console.log('Sender document not found');
                return;
            }

            const senderData = senderDoc.data();
            const senderName = `${senderData.firstName} ${senderData.lastName}`;

            // Create notification message
            const notificationMessage = {
                notification: {
                    title: senderName,
                    body: message.text
                },
                data: {
                    chatId: chatId
                },
                token: recipientToken
            };

            // Send notification
            await admin.messaging().send(notificationMessage);
            console.log('Successfully sent notification');

        } catch (error) {
            console.error('Error sending notification:', error);
        }
    });