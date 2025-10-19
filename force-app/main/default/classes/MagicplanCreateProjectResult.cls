public class MagicplanCreateProjectResult {
    @InvocableVariable @AuraEnabled public String projectId;
    @InvocableVariable @AuraEnabled public String magicplanDeepLink;
    @InvocableVariable @AuraEnabled public String magicplanWebLink;
    @InvocableVariable @AuraEnabled public String salesforceDeepLink;
    @InvocableVariable @AuraEnabled public Id     magicplanProjectRecordId;
    @InvocableVariable @AuraEnabled public String responseJson;
    @InvocableVariable @AuraEnabled public Integer statusCode;
    @InvocableVariable @AuraEnabled public String errorMessage;
}
