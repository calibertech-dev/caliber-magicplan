// Endpoint for magicplan to POST webhook events when a project is updated or exported.
// Configure your magicplan workspace's webhook_url to point to this endpoint on a Salesforce Site/Experience site.
@RestResource(urlMapping='/magicplan/webhook/*')
global with sharing class MagicplanWebhookHandler {

    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String body = (req.requestBody == null) ? null : req.requestBody.toString();
        if (String.isBlank(body)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('No payload received');
            return;
        }

        try {
            Map<String,Object> payload = (Map<String,Object>) JSON.deserializeUntyped(body);

            // Common fields per Magicplan docs (names may vary by event)
            String projectId = (String) payload.get('projectId');
            if (String.isBlank(projectId)) {
                // Try alternate key names if necessary
                projectId = (String) payload.get('id');
            }

            // Upsert the SF mirror record so local state stays fresh
            if (!String.isBlank(projectId)) {
                MagicPlan_Project__c up = new MagicPlan_Project__c();
                up.MagicPlan_Project_Id__c = projectId;
                up.Web_Link__c = 'https://cloud.magicplan.app/estimator/projects/' + projectId;
                up.App_Link__c = 'magicplanstd://project/' + projectId;
                up.Server_Response__c = body;
                up.Last_Sync__c = System.now();

                // If payload has a name, apply it (non-fatal if missing)
                Object nm = payload.get('name');
                if (nm != null) up.Name = String.valueOf(nm);

                // Upsert on the external id field (assumes MagicPlan_Project_Id__c is marked as External ID/Unique in your object)
                upsert up MagicPlan_Project__c.MagicPlan_Project_Id__c;
            }

            // If you want to hand off file processing asynchronously, raise a Platform Event here or enqueue:
            // System.enqueueJob(new ProcessMagicplanFilesQueueable(body));
            // For now we keep the webhook lean and just mirror the project.

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Webhook processed');
        } catch (Exception ex) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error processing webhook: ' + ex.getMessage());
        }
    }
}
