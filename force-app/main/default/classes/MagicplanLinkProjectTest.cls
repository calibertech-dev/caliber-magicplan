@IsTest
private class MagicplanLinkProjectTest {

private class RouterMock implements HttpCalloutMock {
        Integer getCode; String getBody;
        Integer putCode; String putBody;
        Integer patchCode; String patchBody;

        RouterMock withGet(Integer code, String body)  { this.getCode = code;   this.getBody = body;   return this; }
        RouterMock withPut(Integer code, String body)  { this.putCode = code;   this.putBody = body;   return this; }
        RouterMock withPatch(Integer code, String body){ this.patchCode = code; this.patchBody = body; return this; }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            String m = req.getMethod();
            if (m == 'GET') {
                r.setStatusCode(getCode == null ? 200 : getCode);
                r.setBody(getBody == null ? '{"name":"Kitchen Remodel","status":"Completed"}' : getBody);
                r.setStatus('OK');
            } else if (m == 'PUT') {
                r.setStatusCode(putCode == null ? 200 : putCode);
                r.setBody(putBody == null ? '{}' : putBody);
                r.setStatus('OK');
            } else if (m == 'PATCH') {
                r.setStatusCode(patchCode == null ? 200 : patchCode);
                r.setBody(patchBody == null ? '{}' : patchBody);
                r.setStatus('OK');
            } else {
                r.setStatusCode(200); r.setBody('{}'); r.setStatus('OK');
            }
            return r;
        }
    }

    @IsTest
    static void upsert_success_createsProjectAndLinks() {
        Test.setMock(HttpCalloutMock.class,
            new RouterMock()
                .withGet(200, '{"name":"Kitchen Remodel","status":"Completed"}')
        );

        String mpId = 'abc123-proj';
        MagicplanLinkProject.Request req = new MagicplanLinkProject.Request();
        req.magicplanProjectId = mpId;
        req.namedCredentialName = 'Magicplan';
        req.storeServerResponse = true;

        List<MagicplanLinkProject.Result> results =
            MagicplanLinkProject.upsertProject(new List<MagicplanLinkProject.Request>{ req });

        System.assertEquals(1, results.size());
        MagicplanLinkProject.Result res = results[0];
        System.assertEquals(mpId, res.magicplanProjectId);
        System.assertEquals(200, res.statusCode);
        System.assertEquals('magicplanstd://project/' + mpId, res.appDeepLink);
        System.assertEquals('https://cloud.magicplan.app/estimator/projects/' + mpId, res.webLink);
        System.assertEquals(null, res.errorMessage);

        MagicPlan_Project__c rec = [
            SELECT Id, Name, MagicPlan_Project_Id__c, App_Link__c, Web_Link__c, Server_Response__c, Last_Sync__c
            FROM MagicPlan_Project__c
            WHERE MagicPlan_Project_Id__c = :mpId
            LIMIT 1
        ];
        System.assertEquals('Kitchen Remodel', rec.Name);
        System.assert(rec.Last_Sync__c != null);
        System.assert(rec.Server_Response__c != null && rec.Server_Response__c.contains('"name":"Kitchen Remodel"'));
        System.assertEquals('magicplanstd://project/' + mpId, rec.App_Link__c);
        System.assertEquals('https://cloud.magicplan.app/estimator/projects/' + mpId, rec.Web_Link__c);
    }

    @IsTest
    static void upsert_handlesGetFailure_gracefully() {
        Test.setMock(HttpCalloutMock.class, new RouterMock().withGet(404, '{"error":"not found"}'));

        String mpId = 'missing-xyz';
        MagicplanLinkProject.Request req = new MagicplanLinkProject.Request();
        req.magicplanProjectId = mpId;

        List<MagicplanLinkProject.Result> results =
            MagicplanLinkProject.upsertProject(new List<MagicplanLinkProject.Request>{ req });

        System.assertEquals(1, results.size());
        MagicplanLinkProject.Result res = results[0];
        System.assertEquals(404, res.statusCode);
        System.assert(res.errorMessage != null && res.errorMessage.contains('GET failed'));

        System.assertEquals(0, [SELECT COUNT() FROM MagicPlan_Project__c WHERE MagicPlan_Project_Id__c = :mpId]);
    }
}