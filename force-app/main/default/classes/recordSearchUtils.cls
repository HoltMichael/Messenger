public with sharing class recordSearchUtils {

    @AuraEnabled(cacheable=true)
    public static List<objectWrapper> getAllObjects(){
        List<objectWrapper> objs = new List<objectWrapper>();
        for (Schema.SObjectType obj : Schema.getGlobalDescribe().values() ){
            Schema.DescribeSObjectResult objResult = obj.getDescribe();
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
}
