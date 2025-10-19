@IsTest
private class MagicplanGetReportTest {

    // Router that returns the list on first request, and the file bytes on second
    private class ReportRouterMock implements HttpCalloutMock {
        Integer listCode;  String listBody;
        Integer fileCode;  Blob   fileBlob;

        ReportRouterMock withList(Integer code, String body){ listCode=code; listBody=body; return this; }
        ReportRouterMock withFile(Integer code, Blob data)  { fileCode=code; fileBlob=data; return this; } // <-- renamed param

        Integer calls = 0;
        public HttpResponse respond(HttpRequest req) {
            calls++;
            HttpResponse r = new HttpResponse();
            if (calls == 1) {
                r.setStatusCode(listCode == null ? 200 : listCode);
                r.setStatus('OK');
                r.setBody(listBody == null ? '[]' : listBody);
                return r;
            } else {
                r.setStatusCode(fileCode == null ? 200 : fileCode);
                r.setStatus('OK');
                r.setBodyAsBlob(fileBlob == null ? Blob.valueOf('PDF') : fileBlob);
                return r;
            }
        }
    }

    @IsTest
    static void saves_report_to_specific_record() {
        Account a = new Account(Name='Target');
        insert a;

        String filesJson = '['
            + '{"file_name":"Report.pdf","type":"Report PDF","format":"pdf","download_url":"https://example.com/presigned/1"}'
            + ']';

        Test.setMock(HttpCalloutMock.class,
            new ReportRouterMock()
                .withList(200, filesJson)
                .withFile(200, Blob.valueOf('%PDF-1.4 ...'))
        );

        MagicplanGetReport.Request req = new MagicplanGetReport.Request();
        req.projectId = 'mp-123';
        req.reportType = 'report pdf';
        req.namedCredentialName = 'Magicplan';
        req.linkToRecordId = a.Id;
        req.fileTitle = 'Magicplan Report';
        req.replaceExisting = true;

        Test.startTest();
        List<MagicplanGetReport.Result> out =
            MagicplanGetReport.getReportPdfs(new List<MagicplanGetReport.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, out.size());
        MagicplanGetReport.Result res = out[0];
        System.assertEquals(200, res.statusCode);
        System.assertEquals(null, res.errorMessage);
        System.assertNotEquals(null, res.downloadUrl);
        System.assertNotEquals(null, res.contentVersionId);
        System.assertNotEquals(null, res.contentDocumentId);

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :a.Id AND ContentDocumentId = :res.contentDocumentId
        ];
        System.assertEquals(1, links.size());
    }

    @IsTest
    static void auto_attaches_to_magicplan_project_when_no_link_passed() {
        MagicPlan_Project__c p = new MagicPlan_Project__c(
            Name = 'Proj',
            MagicPlan_Project_Id__c = 'mp-abc',
            App_Link__c = 'magicplanstd://project/mp-abc',
            Web_Link__c = 'https://cloud.magicplan.app/estimator/projects/mp-abc'
        );
        insert p;

        String filesJson = '['
            + '{"file_name":"Estimate.pdf","type":"Report PDF","format":"pdf","download_url":"https://example.com/presigned/2"}'
            + ']';

        Test.setMock(HttpCalloutMock.class,
            new ReportRouterMock()
                .withList(200, filesJson)
                .withFile(200, Blob.valueOf('%PDF-1.4 ...'))
        );

        MagicplanGetReport.Request req = new MagicplanGetReport.Request();
        req.projectId = 'mp-abc';
        req.reportType = 'Report PDF';
        req.namedCredentialName = 'Magicplan';

        Test.startTest();
        List<MagicplanGetReport.Result> out =
            MagicplanGetReport.getReportPdfs(new List<MagicplanGetReport.Request>{ req });
        Test.stopTest();

        MagicplanGetReport.Result res = out[0];
        System.assertEquals(null, res.errorMessage);
        System.assertNotEquals(null, res.contentVersionId);

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :p.Id AND ContentDocumentId = :res.contentDocumentId
        ];
        System.assertEquals(1, links.size());
    }

    @IsTest
    static void surfaces_no_match_error() {
        Test.setMock(HttpCalloutMock.class,
            new ReportRouterMock().withList(200, '[]')
        );

        MagicplanGetReport.Request req = new MagicplanGetReport.Request();
        req.projectId = 'mp-none';
        req.reportType = 'Report PDF';

        Test.startTest();
        List<MagicplanGetReport.Result> out =
            MagicplanGetReport.getReportPdfs(new List<MagicplanGetReport.Request>{ req });
        Test.stopTest();

        MagicplanGetReport.Result res = out[0];
        System.assert(res.errorMessage != null && res.errorMessage.contains('No file matching'));
    }

    @IsTest
    static void surfaces_listing_http_error() {
        Test.setMock(HttpCalloutMock.class,
            new ReportRouterMock().withList(403, '{"error":"forbidden"}')
        );

        MagicplanGetReport.Request req = new MagicplanGetReport.Request();
        req.projectId = 'mp-err';

        Test.startTest();
        List<MagicplanGetReport.Result> out =
            MagicplanGetReport.getReportPdfs(new List<MagicplanGetReport.Request>{ req });
        Test.stopTest();

        MagicplanGetReport.Result res = out[0];
        System.assertEquals(403, res.statusCode);
        System.assert(res.errorMessage != null && res.errorMessage.contains('Failed to list files'));
    }
}
