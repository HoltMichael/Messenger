public with sharing class MessengerUtils {
    @AuraEnabled(cacheable=true)
    public static List<User> findUsers(String searchKey) {
        String key = '%' + searchKey + '%';
        system.debug([SELECT Id, Name, Title FROM User WHERE Name LIKE :key WITH SECURITY_ENFORCED LIMIT 50]);
        return [SELECT Id, Name, Title, FullPhotoUrl FROM User WHERE Name LIKE :key WITH SECURITY_ENFORCED LIMIT 500];
    }

    @AuraEnabled(cacheable=true)
    public static List<Group> findGroups(String searchKey) {
        String key = '%' + searchKey + '%';
        system.debug([SELECT Id, Name FROM Group WHERE Name LIKE :key WITH SECURITY_ENFORCED LIMIT 50]);
        return [SELECT Id, Name FROM Group WHERE Name LIKE :key WITH SECURITY_ENFORCED LIMIT 50];
    }
}
