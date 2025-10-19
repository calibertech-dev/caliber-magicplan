@IsTest
private class MagicplanLinkRecordTest {

    // Minimal router-style HttpCalloutMock so we can control PUT/PATCH responses.
    private class RouterMock implements HttpCalloutMock {
        Integer putCode;   String putBody;
        Integer patchCode; String patchBody;

        RouterMock withPut(Integer code, String body)   { this.putCode = code;   this.putBody = body;   return this; }
        RouterMock withPatch(Integer code, String body) { this.patchCode = code; this.patchBody = body; return this; }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            String m = req.getMethod();
            if (m == 'PUT') {
                r.setStatusCode(putCode == null ? 200 : putCode);
                r.setBody(putBody == null ? '{}' : putBody);
                r.setStatus('OK');
            } else if (m == 'PATCH') {
                r.setStatusCode(patchCode == null ? 200 : patchCode);
                r.setBody(patchBody == null ? '{}' : patchBody);
                r.setStatus('OK');
            } else {
                // Default for any unexpected verb to keep tests predictable.
                r.setStatusCode(200);
                r.setBody('{}');
                r.setStatus('OK');
            }
            return r;
        }
    }

    // Helper: create a local MagicPlan_Project__c as the default backlink target.
    private static MagicPlan_Project__c makeProject(String extId, String name) {
        MagicPlan_Project__c p = new MagicPlan_Project__c(
            MagicPlan_Project_Id__c = extId,
            Name = name
        );
        insert p;
        return p;
    }

    @IsTest
    static void writeBacklink_defaultsToMagicplanProjectRecord() {
        // Arrange
        MagicPlan_Project__c proj = makeProject('proj-001', 'Local Anchor');

        // Mock: custom field write succeeds
        Test.setMock(HttpCalloutMock.class, new RouterMock().withPut(200, '{}'));

        MagicplanLinkRecord.Request r = new MagicplanLinkRecord.Request();
        r.magicplanProjectId       = 'proj-001';
        r.magicplanProjectRecordId = proj.Id;   // default target (MagicPlan_Project__c)
        r.customFieldKey           = 'Salesforce';
        r.writeMode                = 'Overwrite';  // default, explicit for clarity

        // Act
        Test.startTest();
        List<MagicplanLinkRecord.Result> results =
            MagicplanLinkRecord.writeBacklink(new List<MagicplanLinkRecord.Request>{ r });
        Test.stopTest();

        // Assert
        System.assertEquals(1, results.size());
        MagicplanLinkRecord.Result res = results[0];
        System.assertEquals(200, res.statusCode, 'PUT should succeed');
        System.assertEquals('Salesforce', res.customFieldKey);
        System.assertEquals('Overwrite', res.writeModeUsed);
        System.assertNotEquals(null, res.writtenUrl, 'URL should be returned');
        // Allow absolute or relative Lightning URL; verify the canonical path shape.
        System.assert(
            res.writtenUrl.contains('/lightning/r/MagicPlan_Project__c/' + proj.Id + '/view'),
            'URL should point to MagicPlan_Project__c record'
        );
        System.assertEquals(null, res.errorMessage, 'No error expected');
    }

    @IsTest
    static void writeBacklink_canTargetArbitraryRecord() {
        // Arrange: create an arbitrary record to link (Account used here)
        Account a = new Account(Name = 'Target Co');
        insert a;

        MagicPlan_Project__c proj = makeProject('proj-002', 'Other Anchor');

        Test.setMock(HttpCalloutMock.class, new RouterMock().withPut(200, '{}'));

        MagicplanLinkRecord.LinkItem li = new MagicplanLinkRecord.LinkItem();
        li.sobjectApiName = 'Account';
        li.recordId       = a.Id;

        MagicplanLinkRecord.Request r = new MagicplanLinkRecord.Request();
        r.magicplanProjectId       = 'proj-002';
        r.magicplanProjectRecordId = proj.Id;   // still required; not used when overrideTarget present
        r.overrideTarget           = li;
        r.customFieldKey           = 'Salesforce';

        // Act
        Test.startTest();
        List<MagicplanLinkRecord.Result> results =
            MagicplanLinkRecord.writeBacklink(new List<MagicplanLinkRecord.Request>{ r });
        Test.stopTest();

        // Assert
        MagicplanLinkRecord.Result res = results[0];
        System.assertEquals(200, res.statusCode);
        System.assertNotEquals(null, res.writtenUrl);
        System.assert(
            res.writtenUrl.contains('/lightning/r/Account/' + a.Id + '/view'),
            'URL should point to Account record'
        );
        System.assertEquals(null, res.errorMessage);
    }

    @IsTest
    static void writeBacklink_appendToNotesWhenPutFailsAndAppendMode() {
        // Arrange: simulate custom field write failure, but notes append success
        Test.setMock(
            HttpCalloutMock.class,
            new RouterMock()
                .withPut(400, '{"error":"cannot write custom fields"}')
                .withPatch(200, '{}')
        );

        MagicPlan_Project__c proj = makeProject('proj-003', 'Append Flow');

        MagicplanLinkRecord.Request r = new MagicplanLinkRecord.Request();
        r.magicplanProjectId       = 'proj-003';
        r.magicplanProjectRecordId = proj.Id;
        r.writeMode                = 'Append';   // enables fallback to notes

        // Act
        Test.startTest();
        List<MagicplanLinkRecord.Result> results =
            MagicplanLinkRecord.writeBacklink(new List<MagicplanLinkRecord.Request>{ r });
        Test.stopTest();

        // Assert: final success from PATCH (notes)
        MagicplanLinkRecord.Result res = results[0];
        System.assertEquals(200, res.statusCode);
        System.assertEquals(null, res.errorMessage, 'Append mode should hide PUT error if PATCH succeeds');
        System.assertNotEquals(null, res.writtenUrl);
        System.assert(res.writtenUrl.contains('/lightning/r/MagicPlan_Project__c/'), 'URL shape check');
    }

    @IsTest
    static void writeBacklink_reportsErrorWhenPutFailsAndNoAppend() {
        // Arrange: PUT fails, and we do not allow append
        Test.setMock(HttpCalloutMock.class, new RouterMock().withPut(422, '{"error":"unprocessable"}'));

        MagicPlan_Project__c proj = makeProject('proj-004', 'No Append');

        MagicplanLinkRecord.Request r = new MagicplanLinkRecord.Request();
        r.magicplanProjectId       = 'proj-004';
        r.magicplanProjectRecordId = proj.Id;
        r.writeMode                = 'Overwrite'; // default behavior

        // Act
        Test.startTest();
        List<MagicplanLinkRecord.Result> results =
            MagicplanLinkRecord.writeBacklink(new List<MagicplanLinkRecord.Request>{ r });
        Test.stopTest();

        // Assert
        MagicplanLinkRecord.Result res = results[0];
        System.assertEquals(422, res.statusCode, 'Should surface PUT failure');
        System.assert(res.errorMessage != null && res.errorMessage.contains('Custom field write failed'),
            'Error message should describe failed PUT');
    }
}
