public class MagicplanCreateProjectRequest {
    // Required
    @InvocableVariable @AuraEnabled public String projectName;

    // Optional correlation
    @InvocableVariable @AuraEnabled public String externalReferenceId;

    // Location/context
    @InvocableVariable @AuraEnabled public String type;
    @InvocableVariable @AuraEnabled public String address1;
    @InvocableVariable @AuraEnabled public String city;
    @InvocableVariable @AuraEnabled public String state;
    @InvocableVariable @AuraEnabled public String zip;
    @InvocableVariable @AuraEnabled public String country;
    @InvocableVariable @AuraEnabled public String notes;

    // Back-link (to build Lightning URL)
    @InvocableVariable @AuraEnabled public String salesforceRecordId;
    @InvocableVariable @AuraEnabled public String salesforceObjectApiName;

    // Backlink mode: CustomField | Notes | None  (default = CustomField)
    @InvocableVariable @AuraEnabled public String backlinkMode;

    // Magicplan custom field plumbing
    @InvocableVariable @AuraEnabled public String customFieldKey;      // default: "Salesforce"
    @InvocableVariable @AuraEnabled public String customFieldGroupId;  // optional

    // HTTP / Flow convenience
    @InvocableVariable @AuraEnabled public String namedCredentialName; // default: "Magicplan"
    @InvocableVariable @AuraEnabled public String headersJson;         // optional JSON
    @InvocableVariable @AuraEnabled public String extraBodyJson;       // optional JSON
}
