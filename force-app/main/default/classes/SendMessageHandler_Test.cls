@isTest
public with sharing class SendMessageHandler_Test {
    @TestSetup
    static void makeData(){
        User u1 = new User(
                            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
                            LastName = 'last',
                            Email = 'michael.holt@example.com',
                            Username = 'michael.holt.test.001@example.com' + System.currentTimeMillis(),
                            CompanyName = 'TEST',
                            Title = 'title',
                            Alias = 'alias',
                            TimeZoneSidKey = 'Europe/London',
                            EmailEncodingKey = 'UTF-8',
                            LanguageLocaleKey = 'en_US',
                            LocaleSidKey = 'en_US');
        User u2 = new User(
                            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
                            LastName = 'last',
                            Email = 'michael.holt@example.com',
                            Username = 'michael.holt.test.002@example.com' + System.currentTimeMillis(),
                            CompanyName = 'TEST',
                            Title = 'title',
                            Alias = 'alias',
                            TimeZoneSidKey = 'America/Los_Angeles',
                            EmailEncodingKey = 'UTF-8',
                            LanguageLocaleKey = 'en_US',
                            LocaleSidKey = 'en_US');
        
        insert new List<User>{u1,u2};
    }


    /*
        sendMessageTest
        Check the sendMessage method in the SendMessageHandler Class, using a dummy encryption key
    */
    @isTest
    public static void sendMessageTest(){
        //The same dummy key as used in the SendMessageHandler Class
        String cryptoKeyDummy = '71Hnt5gqRX0N5CWUMWbBwozy5H8mSzXNtPArOJUhSao=';
        String nameStyle = '%michael.holt.test%';
        List<User> users = [SELECT id, name, username FROM User WHERE username like: nameStyle];
        System.debug(users);
        Test.startTest();
            System.runAs(users[0]){
                sendMessageHandler.sendMessage('test message', users[0].id, users[1].id, users[0].name);
            }
        Test.stopTest();
        
        List<MHolt__Chat_Message__c> msgs = [SELECT Id, name, OwnerId, Owner.Name, MHolt__From_Name__c, MHolt__Message__c, MHolt__Participants__c, createdDate FROM MHolt__Chat_Message__c];
        MHolt__Chat_Message__c msg = msgs[0];
        //Check we have a message in the database
        System.assertEquals(1, msgs.size());
        //Check we have encrypted the message, so it should no longer say "test message
        System.assertNotEquals('test message', msg.MHolt__Message__c);
        System.assert(msg.MHolt__Participants__c.contains(users[1].id));
        System.assert(msg.MHolt__Participants__c.contains(users[0].id));
        System.assertEquals(users[0].id, msg.OwnerId);
        
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyDummy);
        Blob base64EncryptedMessage = EncodingUtil.base64decode(msg.MHolt__Message__c);
        Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, base64EncryptedMessage);
        //Check the decrypted string comes back and matches
        System.assertEquals('test message', decryptedData.toString());
    }

    /*
        publishEventTest
        Check the sendMessage method in the SendMessageHandler Class, asserting that a DML statement has been consumed
        And thus, a platform event has fired in the corresponding method
    */
    @isTest
    public static void publishEventTest(){
        Test.startTest();
            SendMessageHandler.publishEvent('recip', 'sdr', 'nm', 'msg', 'id');
            System.assertEquals(1, Limits.getDMLStatements());
        Test.stopTest();
    }

    /*
        postToChatterTest
        Checks the postToChatter method in the SendMessageHandler class. A series of 20 messages are 
        selected to be posted to Chatter. The first should be posted as a feed item and the remaining 19
        should be posted as comments on that feed item
    */
    @isTest
    public static void postToChatterTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> users = [SELECT id, name, username FROM User WHERE username like: nameStyle];
        System.runAs(users[0]){
            for(integer i = 0; i < 20; i++){
                sendMessageHandler.sendMessage('test message: ' + i, users[0].id, users[1].id, users[0].name);
            }
        }
        List<Id> msgIds = new List<Id>(new Map<Id, MHolt__Chat_Message__c>([SELECT Id FROM MHolt__Chat_Message__c]).keySet());
        Test.startTest();
            sendMessageHandler.postToChatter(msgIds, users[0].id);
        Test.stopTest();
        List<FeedItem> ChatterFeeds = [SELECT id, LastEditById, Body, CommentCount, ParentId FROM FeedItem];
        //Check there is just a single feed item in the org
        System.assertEquals(1, ChatterFeeds.Size());
        //Check the feed item has 19 comments on it (first post is the Feed Item itself: 20 - 1 = 19)
        System.assertEquals(19, ChatterFeeds[0].CommentCount);
        //Check the message on the feed item is correct
        System.assertEquals('test message: 0', ChatterFeeds[0].Body);
        //Check that the message was posted to the correct record, in this case, the user's feed
        System.assertEquals(users[0].id, ChatterFeeds[0].ParentId);
    }

    /*
        shareContentTest
        Check that the shareContent method in the SendMessageHandler class is correctly sharing 
        uploaded records with their recipients
    */
    @isTest
    public static void shareContentTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> users = [SELECT id, name, username FROM User WHERE username like: nameStyle];
        System.runAs(users[0]){
            ContentVersion cv1 = new ContentVersion(Title = 'Messenger Test Content', PathOnClient = 'messenger.pdf', VersionData = Blob.valueOf('Test Content'), IsMajorVersion = true);
            ContentVersion cv2 = new ContentVersion(Title = 'Messenger Test Content', PathOnClient = 'messenger.pdf', VersionData = Blob.valueOf('Test Content'), IsMajorVersion = true);
            insert new List<ContentVersion>{cv1,cv2};

            //Need to pass a list of document IDs to the shareContent method, so get those out, now that we've put versions in (can't insert ContentDocument)
            List<Id> docIds = new List<Id>(new Map<Id, ContentDocument>([SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument]).keySet());
            Test.startTest();
                String result = SendMessageHandler.shareContent(users[1].id, docIds);
            Test.stopTest();
        
            List<ContentDocumentLink> cdls = [SELECT id, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId =: users[1].id];

            //Check that both files have been shared with the user
            System.assertEquals(2, cdls.size());
            //Check that the record has been shared with the correct user
            System.assertEquals(users[1].id, cdls[0].LinkedEntityId);
        }
    }

    /*
        getTimeInTimezoneForUsersTest
        Check the getTimeInTimezoneForUsers method in the SendMessageHandler Class
        Test for 2 users in different timezones and check that the timezone returned
        has the correct offset. For both users, get the time in GMT now. Then get the time local to those users
        Deduct one from the other to get the offset and check the map has the correct time assigned.
    */
    @isTest
    public static void getTimeInTimezoneForUsersTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> users = [SELECT id,TimeZoneSidKey, name, username FROM User WHERE username like: nameStyle];
        Test.startTest();
            system.runAs(users[0]){
                DateTime now = DateTime.now();
                Map<Id, DateTime> timesByUsers = SendMessageHandler.getTimeInTimezoneForUsers(users, now);
                Long offset = DateTime.newInstance(now.date(), now.time()).getTime() - DateTime.newInstance(now.dateGmt(), now.timeGmt()).getTime();
                Integer offSetMinutes = Integer.valueOf(offset) / (60 * 1000);
                system.assertEquals(now.addMinutes(offSetMinutes),  timesByUsers.get(users[0].id));
            }

            system.runAs(users[1]){
                DateTime now = DateTime.now();
                Map<Id, DateTime> timesByUsers = SendMessageHandler.getTimeInTimezoneForUsers(users, now);
                Long offset = DateTime.newInstance(now.date(), now.time()).getTime() - DateTime.newInstance(now.dateGmt(), now.timeGmt()).getTime();
                Integer offSetMinutes = Integer.valueOf(offset) / (60 * 1000);
                system.assertEquals(now.addMinutes(offSetMinutes),  timesByUsers.get(users[1].id));
            }
        Test.stopTest();
    }

    /*
        getChatHistoryTest
        Check that the getChatHistory method works as designed. Request a limited number of records and
        ensure they are returned from the database and are decrypted
    */
    @isTest
    public static void getChatHistoryTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> users = [SELECT id, name, username FROM User WHERE username like: nameStyle];

        System.runAs(users[0]){
            //Insert 20 messages into the DB, using the sendMessage method
            for(integer i = 0; i < 20; i++){
                sendMessageHandler.sendMessage('test message', users[0].id, users[1].id, users[0].name);
            }

            Test.startTest();
                //Call the getChatHistory method and request 15 messages for these 2 users
                List<SendMessageHandler.MessageWrapper> msgs = SendMessageHandler.getChatHistory(users[0].id, users[1].id, 15);
            Test.stopTest();

            //Check that the messages are encrypted whilst in the database
            List<MHolt__Chat_Message__c> encryptedMsgs = [SELECT id, MHolt__Message__c FROM MHolt__Chat_Message__c];
            for(MHolt__Chat_Message__c enc : encryptedMsgs){
                system.assertNotEquals('test message', enc.MHolt__Message__c);
            }

            //Check that 15 records have been pulled back and verify that those messages have been decrypted
            System.assertEquals(15, msgs.size());
            for(SendMessageHandler.MessageWrapper msg : msgs){
                System.assertEquals('test message', msg.message);
            }
        }
    }


    /*
        decryptMessageTest
        Insert a message using the sendMessage method and check the String has been encrypted
        Use the decryptMessage method to decrypt the message and ensure this works
    */
    @isTest
    public static void decryptMessageTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> users = [SELECT id, name, username FROM User WHERE username like: nameStyle];

        System.runAs(users[0]){
            String message = 'This is a test String';
            sendMessageHandler.sendMessage(message, users[0].id, users[1].id, users[0].name);
            MHolt__Chat_Message__c msg = [SELECT id, MHolt__Message__c FROM MHolt__Chat_Message__c][0];
            System.assertNotEquals('test message', msg.MHolt__Message__c);

            Test.startTest();
                SendMessageHandler.MessageWrapper msgWrap = SendMessageHandler.decryptMessage(msg.MHolt__Message__c, Userinfo.getUserId());
            Test.stopTest();

            System.assertEquals(message, msgWrap.message);
        }
    }
}
