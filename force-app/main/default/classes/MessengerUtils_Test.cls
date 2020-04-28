@isTest
public with sharing class MessengerUtils_Test {
    @TestSetup
    static void makeData(){
        User u1 = new User(
                            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
                            FirstName = 'Michael',
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
                            FirstName = 'Michael',
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
        Test.startTest();
            //Test getting multiple records back
            System.assertEquals(2, MessengerUtils.findUsers('michael').size());
            //Test getting one record back
            System.assertEquals(1, MessengerUtils.findUsers('one').size());
            //Test getting no records back
            System.assertEquals(0, MessengerUtils.findUsers('xyz').size());
        Test.stopTest();
    }

    /*
        findGroupsTest
        Test the findGroups method, so that the group search functionality works as intended
    */
    @isTest
    public static void findGroupsTest(){
        List<Group> groups = new List<Group>();
        for(integer i = 0; i < 10; i++){
            Group g = new Group(name = 'test: ' + i);
            groups.add(g);
        }
        insert groups;
        
        test.startTest();
            //Test getting multiple records back
            System.assertEquals(10, MessengerUtils.findGroups('test: ').size());
            //Test getting one record back
            System.assertEquals(1, MessengerUtils.findGroups('test: 1').size());
            //Test getting nothing back
            System.assertEquals(0, MessengerUtils.findGroups('test: X').size());
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
