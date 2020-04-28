@isTest
public with sharing class RecordSearchUtils_Test {
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
        getAllObjectsTest
        Test that the getAllObjects method is returning objects. This value is going to vary on an org by org
        basis, but assuming here that at least one object is visible to the user, has chatter field enabled and has a name field
        Check that an object which doesn't have a standard "Name" field, such as "Case" is not returned
    */
    @isTest
    public static void getAllObjectsTest(){
        String nameStyle = '%michael.holt.test.001%';
        User user = [SELECT id, name, username FROM User WHERE username like: nameStyle][0];
        Test.startTest();
            System.runAs(user){
                List<recordSearchUtils.objectWrapper> objs = recordSearchUtils.getAllObjects();
                System.assert(objs.size() > 0);
                List<String> names = new List<String>();
                for(recordSearchUtils.objectWrapper obj : objs){
                    names.add(obj.label);
                }
                System.assert(!names.contains('Case'));
            }
        Test.stopTest();
    }


    /*
        findRecordsTest
        Test that the findRecords method pulls back the expected records when called
    */
    @isTest
    public static void findRecordsTest(){
        List<Account> accs = new List<Account>();
        List<Opportunity> opps = new List<Opportunity>();
        List<Case> cases = new List<Case>();
        for(integer i = 0; i < 10; i++){
            Account a = new Account(name = 'Acc ' + i);
            accs.add(a);
        }
        insert accs;

        for(integer i = 0; i < 10; i++){
            Opportunity opp = new Opportunity(name = 'Opp: ' + i, Account = accs[0], stageName='New', CloseDate=System.Today());
            opps.add(opp);
        }
        insert opps;
        for(integer i = 0; i < 10; i++){
            Case c = new Case(Account = accs[0], subject = 'case');
            cases.add(c);
        }
        insert cases;
        
        Test.startTest();
            //10 accounts should come back
            System.assertEquals(10, recordSearchUtils.findRecords('Acc','Account','Name').size());
            //1 account should come back
            System.assertEquals(1, recordSearchUtils.findRecords('Acc 1','Account','Name').size());
            //No accounts are called XYZ, so no accounts should come back
            System.assertEquals(0, recordSearchUtils.findRecords('XYZ','Account','Name').size());
            //10 opportunities should come back
            System.assertEquals(10, recordSearchUtils.findRecords('Opp','Opportunity','Name').size());
            //No field "Name" on case, so it's currently not supported and not returned
            System.assertEquals(0, recordSearchUtils.findRecords('Case','Case','Name').size());
            //Test using a different field, to retreieve cases, for a future version
            System.assertEquals(10, recordSearchUtils.findRecords('case','Case','Subject').size());
        Test.stopTest();
    }
}
