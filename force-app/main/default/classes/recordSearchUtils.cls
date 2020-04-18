public with sharing class recordSearchUtils {

    @AuraEnabled(cacheable=true)
    public static List<objectWrapper> getAllObjects(){
        List<objectWrapper> objs = new List<objectWrapper>();
        for (Schema.SObjectType obj : Schema.getGlobalDescribe().values() ){
            system.debug(obj);
            Schema.DescribeSObjectResult objResult = obj.getDescribe();
            system.debug(objResult);
            if(objResult.isAccessible() && objResult.isFeedEnabled()){
                objs.add(new objectWrapper(objResult.getName(), objResult.getLabel()));
            }
        }
        return objs;
    } 
    
    @AuraEnabled(cacheable = true)
    public static List<SObject> findRecords(String searchKey, String objectName, String searchField){
        String key = '%' + searchKey + '%';
        String QUERY = 'Select Id, '+searchField+' From '+objectName +' Where '+searchField +' LIKE :key';
        System.debug(System.LoggingLevel.DEBUG, QUERY);
        List<SObject> sObjectList = Database.query(QUERY);
        return sObjectList;
    }

    public class objectWrapper{
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
            
        public objectWrapper(String val, String lab){
            value = val;
            label = lab;
        }

    }

    /*@AuraEnabled
    public static List<ObjectPermissions> getAllObjects(){
        String desireUserId = UserInfo.getUserId(); // or pass any other user id.
        User u = [select profileId from user where id =: '00526000005IJi4'];
        String profileId = u.profileId;
        
        List<ObjectPermissions> objPermissionList = [SELECT Id, SObjectType, PermissionsRead 
                                                    FROM ObjectPermissions 
                                                    WHERE parentid in (select id from permissionset where PermissionSet.Profile.Id=: profileId)];
        return objPermissionList;
    }*/
}
