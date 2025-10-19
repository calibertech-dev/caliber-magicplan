@IsTest
private class MagicplanCreateProjectTest {

    // Mock for POST /projects and optional PUT/PATCH backlink writes
    private class RouterMock implements HttpCalloutMock {
        Integer postCode;  String postBody;
        Integer putCode;   String putBody;
        Integer patchCode; String patchBody;

        RouterMock withPost(Integer c, String b){ postCode=c; postBody=b; return this; }
        RouterMock withPut(Integer c, String b) { putCode=c;  putBody=b;  return this; }
        RouterMock withPatch(Integer c, String b){ patchCode=c; patchBody=b; return this; }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            String m = req.getMethod();
            if (m == 'POST') {
                r.setStatusCode(postCode == null ? 201 : postCode);
                r.setStatus('Created');
                r.setBody(postBody == null ? '{"id":"mp-123","name":"Kitchen"}' : postBody);
            } else if (m == 'PUT') {
                r.setStatusCode(putCode == null ? 200 : putCode);
                r.setStatus('OK');
                r.setBody(putBody == null ? '{}' : putBody);
            } else if (m == 'PATCH') {
                r.setStatusCode(patchCode == null ? 200 : patchCode);
                r.setStatus('OK');
                r.setBody(patchBody == null ? '{}' : patchBody);
            } else {
                r.setStatusCode(200); r.setStatus('OK'); r.setBody('{}');
            }
            return r;
        }
    }

    @IsTest
    static void create_success_upsertsAndWritesCustomField() {
        // Arrange callouts
        Test.setMock(HttpCalloutMock.class,
            new RouterMock()
                .withPost(201, '{"id":"mp-abc","name":"My New Project"}')
                .withPut(200, '{}')
        );

        // Backlink target
        Account a = new Account(Name='A');
        insert a;

        // Request
        MagicplanCreateProjectRequest r = new MagicplanCreateProjectRequest();
        r.projectName              = 'My New Project';
        r.salesforceObjectApiName  = 'Account';
        r.salesforceRecordId       = a.Id;
        r.backlinkMode             = 'CustomField';
        r.customFieldKey           = 'Salesforce';
        r.namedCredentialName      = 'Magicplan';

        // Act
        Test.startTest();
        List<MagicplanCreateProjectResult> results =
            MagicplanCreateProject.createProjects(new List<MagicplanCreateProjectRequest>{ r });
        Test.stopTest();

        // Assert
        System.assertEquals(1, results.size());
        MagicplanCreateProjectResult res = results[0];
        System.assertEquals(201, res.statusCode);
        System.assertEquals('mp-abc', res.projectId);
        System.assert(res.magicplanDeepLink.endsWith('mp-abc'), 'App deeplink should end with project id');
        System.assert(res.magicplanWebLink.contains('/estimator/projects/mp-abc'), 'Web link should contain project id');
        System.assertNotEquals(null, res.salesforceDeepLink, 'SF backlink should be returned');
        System.assertEquals(null, res.errorMessage);

        MagicPlan_Project__c p = [
            SELECT Id, Name, MagicPlan_Project_Id__c, App_Link__c, Web_Link__c, Server_Response__c, Last_Sync__c
            FROM MagicPlan_Project__c WHERE MagicPlan_Project_Id__c = 'mp-abc' LIMIT 1
        ];
        System.assertEquals('My New Project', p.Name);
        System.assertNotEquals(null, p.Last_Sync__c);
        System.assert(p.Server_Response__c != null && p.Server_Response__c.contains('"id":"mp-abc"'));
        System.assertEquals(p.Id, res.magicplanProjectRecordId);
    }

    @IsTest
    static void create_success_appendNotesWhenRequested() {
        // Arrange callouts: POST ok, PATCH ok
        Test.setMock(HttpCalloutMock.class,
            new RouterMock()
                .withPost(201, '{"id":"mp-notes","name":"Notey"}')
                .withPatch(200, '{}')
        );

        Account a = new Account(Name='B');
        insert a;

        MagicplanCreateProjectRequest r = new MagicplanCreateProjectRequest();
        r.projectName              = 'Notey';
        r.salesforceObjectApiName  = 'Account';
        r.salesforceRecordId       = a.Id;
        r.backlinkMode             = 'Notes';

        Test.startTest();
        List<MagicplanCreateProjectResult> results =
            MagicplanCreateProject.createProjects(new List<MagicplanCreateProjectRequest>{ r });
        Test.stopTest();

        System.assertEquals(1, results.size());
        MagicplanCreateProjectResult res = results[0];
        System.assertEquals(201, res.statusCode);
        System.assertEquals('mp-notes', res.projectId);
        System.assertEquals(null, res.errorMessage);
    }

    @IsTest
    static void create_handlesHttpError() {
        // Arrange: POST fails
        Test.setMock(HttpCalloutMock.class, new RouterMock().withPost(400, '{"error":"bad"}'));

        MagicplanCreateProjectRequest r = new MagicplanCreateProjectRequest();
        r.projectName = 'Nope';

        Test.startTest();
        List<MagicplanCreateProjectResult> results =
            MagicplanCreateProject.createProjects(new List<MagicplanCreateProjectRequest>{ r });
        Test.stopTest();

        System.assertEquals(1, results.size());
        MagicplanCreateProjectResult res = results[0];
        System.assertEquals(400, res.statusCode);
        System.assert(res.errorMessage != null && res.errorMessage.contains('HTTP 400'));
    }
}
