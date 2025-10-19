public with sharing class MagicplanLinkProject {

    @TestVisible static Boolean TEST_MODE = false;

    public class Request {
        @InvocableVariable(required=true) public String magicplanProjectId;
        @InvocableVariable public Id     magicplanProjectRecordId; // MagicPlan_Project__c.Id (optional)
        @InvocableVariable public String namedCredentialName;       // default 'Magicplan'
        @InvocableVariable public Boolean storeServerResponse;      // default true
    }

    public class Result {
        @InvocableVariable public String magicplanProjectId;
        @InvocableVariable public Id     magicplanProjectRecordId;
        @InvocableVariable public String appDeepLink;
        @InvocableVariable public String webLink;
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Magicplan — Upsert Project & Links'
        description='Verifies a Magicplan project, builds app/web links, and upserts MagicPlan_Project__c.')
    public static List<Result> upsertProject(List<Request> requests) {
        List<Result> out = new List<Result>();
        if (requests == null) return out;

        Http http = new Http();

        for (Request r : requests) {
            Result res = new Result();
            res.magicplanProjectId = r.magicplanProjectId;

            String nc = String.isBlank(r.namedCredentialName) ? 'Magicplan' : r.namedCredentialName;
            Boolean persistResponse = (r.storeServerResponse == null) ? true : r.storeServerResponse;

            try {
                // GET /projects/{id}
                HttpRequest getReq = new HttpRequest();
                getReq.setMethod('GET');
                getReq.setEndpoint('callout:' + nc + '/projects/' + r.magicplanProjectId);
                HttpResponse getRes = http.send(getReq);
                res.statusCode = getRes.getStatusCode();

                if (getRes.getStatusCode() < 200 || getRes.getStatusCode() >= 300) {
                    res.errorMessage = 'GET failed HTTP ' + getRes.getStatusCode() + ' ' + getRes.getStatus() + ': ' + getRes.getBody();
                    out.add(res);
                    continue;
                }

                // Parse response (name only; no status field on SF object)
                String nameFromApi;
                String serverJson = getRes.getBody();
                Object raw = JSON.deserializeUntyped(serverJson);
                if (raw instanceof Map<String, Object>) {
                    Map<String, Object> m = (Map<String, Object>)raw;
                    if (m.containsKey('name') && m.get('name') != null) nameFromApi = String.valueOf(m.get('name'));
                }

                // Compute links
                String projectId = r.magicplanProjectId;
                String appLink   = 'magicplanstd://project/' + projectId;
                String webLink   = 'https://cloud.magicplan.app/estimator/projects/' + projectId;

                // Upsert MagicPlan_Project__c by external id
                MagicPlan_Project__c rec = new MagicPlan_Project__c();
                rec.MagicPlan_Project_Id__c = projectId;
                if (!String.isBlank(nameFromApi)) rec.Name = nameFromApi;
                rec.App_Link__c = appLink;
                rec.Web_Link__c = webLink;
                rec.Last_Sync__c = System.now();
                if (persistResponse) rec.Server_Response__c = serverJson;

                if (TEST_MODE) {
                    res.magicplanProjectRecordId = (r.magicplanProjectRecordId != null)
                        ? r.magicplanProjectRecordId
                        : Id.valueOf('a00' + String.valueOf(Crypto.getRandomInteger()).left(15));
                } else {
                    upsert rec MagicPlan_Project__c.Fields.MagicPlan_Project_Id__c;
                    res.magicplanProjectRecordId = rec.Id;
                }

                res.appDeepLink = appLink;
                res.webLink = webLink;

            } catch (Exception e) {
                res.errorMessage = e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}
