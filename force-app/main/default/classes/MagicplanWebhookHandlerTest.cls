@IsTest
private class MagicplanWebhookHandlerTest {

    @IsTest
    static void upserts_project_on_webhook() {
        // Simulate inbound request
        String body = '{"projectId":"mp-xyz","name":"Main House","status":"exported"}';
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/magicplan/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MagicplanWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        MagicPlan_Project__c p = [
            SELECT Id, Name, MagicPlan_Project_Id__c, Web_Link__c, App_Link__c, Server_Response__c, Last_Sync__c
            FROM MagicPlan_Project__c
            WHERE MagicPlan_Project_Id__c = 'mp-xyz'
            LIMIT 1
        ];
        System.assertEquals('Main House', p.Name);
        System.assert(p.Server_Response__c != null && p.Server_Response__c.contains('"mp-xyz"'));
        System.assert(p.Web_Link__c.contains('/estimator/projects/mp-xyz'));
        System.assert(p.App_Link__c.endsWith('mp-xyz'));
    }

    @IsTest
    static void returns_400_when_empty_body() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/magicplan/webhook';
        req.httpMethod = 'POST';

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MagicplanWebhookHandler.handleWebhook();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
