@isTest
public with sharing class MessengerUtils_Test {
    @TestSetup
    static void makeData(){
        User u1 = new User(
                            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
                            FirstName = 'MichaelXTest001',
                            LastName = 'one',
                            Email = 'puser000@amamama.com',
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
                            FirstName = 'MichaelXTest002',
                            LastName = 'two',
                            Email = 'puser000@amamama.com',
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
        findUsersTest
        Test the findUsers method, so that the user search functionality works as intended
    */
    @isTest
    public static void findUsersTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> user = [SELECT id, name, username FROM User WHERE username like: nameStyle];
        Test.startTest();
            //Nobody in the org has the perm set, so expect 0 results
            System.assertEquals(0, MessengerUtils.findUsers('MichaelXTest00').size());
            //Assign permission set to 1 user and expect 1 result
            PermissionSet ps1 = [SELECT Id FROM PermissionSet WHERE Name = 'Messenger_User' AND NamespacePrefix='MHolt'];
            insert new PermissionSetAssignment(AssigneeId = user[0].id, PermissionSetId = ps1.Id);
            System.assertEquals(1, MessengerUtils.findUsers('MichaelXTest00').size());
            //Assign permission set to second user and expect 2 results
            PermissionSet ps2 = [SELECT Id FROM PermissionSet WHERE Name = 'Messenger_User' AND NamespacePrefix='MHolt'];
            insert new PermissionSetAssignment(AssigneeId = user[1].id, PermissionSetId = ps2.Id);
            System.assertEquals(2, MessengerUtils.findUsers('MichaelXTest00').size());
            //Make sure it only pulls back users matching the search criteria, when multiple users have the perm set
            System.assertEquals(1, MessengerUtils.findUsers('MichaelXTest002').size());
        Test.stopTest();
    }

    /*
        findGroupsTest
        Test the findGroups method, so that the group search functionality works as intended
    */
    @isTest
    public static void findGroupsTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> user = [SELECT id, name, username FROM User WHERE username like: nameStyle];

        //Make some groups, private and public, it shouldn't make a difference
        List<CollaborationGroup> groups = new List<CollaborationGroup>();
        for(integer i = 0; i < 10; i++){
            CollaborationGroup g = new CollaborationGroup();
            if(i<5){
                g = new CollaborationGroup(name = 'test: ' + i, CollaborationType='Public');
            }else{
                g = new CollaborationGroup(name = 'test: ' + i, CollaborationType='Private');
            }

            groups.add(g);
        }
        insert groups;
        //Add the first user to 4 groups
        CollaborationGroupMember gm1 = new CollaborationGroupMember(MemberId = user[0].id, CollaborationGroupId= groups[0].id);
        CollaborationGroupMember gm2 = new CollaborationGroupMember(MemberId = user[0].id, CollaborationGroupId= groups[1].id);
        CollaborationGroupMember gm3 = new CollaborationGroupMember(MemberId = user[0].id, CollaborationGroupId= groups[2].id);
        CollaborationGroupMember gm4 = new CollaborationGroupMember(MemberId = user[0].id, CollaborationGroupId= groups[3].id);
        //Add the second user to 7 groups, including 1 crossover
        CollaborationGroupMember gm5 = new CollaborationGroupMember(MemberId = user[1].id, CollaborationGroupId= groups[3].id);
        CollaborationGroupMember gm6 = new CollaborationGroupMember(MemberId = user[1].id, CollaborationGroupId= groups[4].id);
        CollaborationGroupMember gm7 = new CollaborationGroupMember(MemberId = user[1].id, CollaborationGroupId= groups[5].id);
        CollaborationGroupMember gm8 = new CollaborationGroupMember(MemberId = user[1].id, CollaborationGroupId= groups[6].id);
        CollaborationGroupMember gm9 = new CollaborationGroupMember(MemberId = user[1].id, CollaborationGroupId= groups[7].id);
        CollaborationGroupMember gm10 = new CollaborationGroupMember(MemberId = user[1].id, CollaborationGroupId= groups[8].id);
        CollaborationGroupMember gm11 = new CollaborationGroupMember(MemberId = user[1].id, CollaborationGroupId= groups[9].id);
        insert new List<CollaborationGroupMember>{gm1,gm2,gm3,gm4,gm5,gm6,gm7,gm8,gm9,gm10,gm11};

        test.startTest();
            System.RunAs(user[0]){
                System.assertEquals(4, MessengerUtils.findGroups('').size());
                System.assertEquals(4, MessengerUtils.findGroups('test').size());
                System.assertEquals(1, MessengerUtils.findGroups('1').size());
                System.assertEquals(0, MessengerUtils.findGroups('4').size());
            }
            System.RunAs(user[1]){
                System.assertEquals(7, MessengerUtils.findGroups('').size());
                System.assertEquals(7, MessengerUtils.findGroups('test').size());
                System.assertEquals(1, MessengerUtils.findGroups('7').size());
                System.assertEquals(0, MessengerUtils.findGroups('1').size());
            }
        test.stopTest();
    }

    /*
        getOfflineMessages

    */
    @isTest
    public static void getOfflineMessagesTest(){
        String nameStyle = '%michael.holt.test%';
        List<User> users = [SELECT id, name, username FROM User WHERE username like: nameStyle];

        test.startTest();
            system.runAs(users[0]){
                sendMessageHandler.sendMessage('test message', users[0].id, users[1].id, users[0].name);
                MHolt__Chat_Message__c msg = [SELECT id, MHolt__Read__c FROM MHolt__Chat_Message__c][0];
                msg.MHolt__Read__c = true;
                update msg;
                //Check that no messages are returned if inserted messages have already been marked as 'read'
                System.assertEquals(0, MessengerUtils.getOfflineMessages().size());
                sendMessageHandler.sendMessage('test message', users[0].id, users[1].id, users[0].name);
                //Check that a message is returned and contains the name of the user who sent the message
                //if a message has not been marked as 'read'
                System.assertEquals(1, MessengerUtils.getOfflineMessages().size());
                System.assertEquals(users[0].name, MessengerUtils.getOfflineMessages().get(users[0].id));
            }
        test.stopTest();
    }


    /*
        hasUserAndEventAccessTest
        Test that the hasUserAccess method returns true when users have access to the User object
    */
    @isTest
    public static void hasUserAndEventAccessTest(){
        String nameStyle = '%michael.holt.test.001%';
        User user = [SELECT id, name, username FROM User WHERE username like: nameStyle][0];
        test.startTest();
            System.RunAs(user){
                System.assertEquals(true,MessengerUtils.hasUserAndEventAccess());
            }
        test.stopTest();
    }
}
