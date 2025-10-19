@IsTest
private class MagicplanSearchRemoteProjectsTest {

    // Call-order based router: 1st call -> firstCode/body, subsequent -> secondCode/body
    private class GetRouterMock implements HttpCalloutMock {
        Integer firstCode;  String firstBody;
        Integer secondCode; String secondBody;
        Integer calls = 0;

        GetRouterMock first(Integer c, String b){ firstCode=c;  firstBody=b;  return this; }
        GetRouterMock second(Integer c, String b){ secondCode=c; secondBody=b; return this; }

        public HttpResponse respond(HttpRequest req) {
            calls++;
            HttpResponse r = new HttpResponse();
            if (calls == 1) {
                r.setStatusCode(firstCode == null ? 200 : firstCode);
                r.setStatus('OK');
                r.setBody(firstBody == null ? '[]' : firstBody);
            } else {
                r.setStatusCode(secondCode == null ? 200 : secondCode);
                r.setStatus('OK');
                r.setBody(secondBody == null ? '[]' : secondBody);
            }
            return r;
        }
    }

    // Mock that simulates a transport failure by throwing from respond()
    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Simulate a low-level callout error
            throw new CalloutException('simulated transport failure');
        }
    }

    @IsTest
    static void remote_search_paginates_and_filters() {
        String page1 = '{"projects":['
            + '{"id":"p-001","name":"Elm Remodel","address":{"address_1":"12 Elm","city":"Boise","state":"ID","zip":"83702","country":"US"}},'
            + '{"id":"p-002","name":"Maple Addition","address":{"address_1":"99 Maple","city":"Austin","state":"TX","zip":"78701","country":"US"}}'
            + ']}';

        Test.setMock(HttpCalloutMock.class,
            new GetRouterMock()
                .first(200, page1)
                .second(200, '{"projects":[]}')
        );

        MagicplanSearchRemoteProjects.Request req = new MagicplanSearchRemoteProjects.Request();
        req.searchText = 'maple';
        req.maxResults = 25;
        req.pageSize   = 100;
        req.maxPages   = 3;
        req.namedCredentialName = 'Magicplan';

        Test.startTest();
        List<MagicplanSearchRemoteProjects.Row> rows =
            MagicplanSearchRemoteProjects.search(new List<MagicplanSearchRemoteProjects.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('p-002', rows[0].id);
        System.assertEquals('Maple Addition', rows[0].name);
        System.assertEquals('Austin', rows[0].city);
        System.assertEquals('TX', rows[0].state);
    }

    @IsTest
    static void remote_search_switches_to_offset_on_first_4xx() {
        Test.setMock(HttpCalloutMock.class,
            new GetRouterMock()
                .first(400, '{"error":"use offset"}')
                .second(200, '{"projects":[{"id":"p-OK","name":"Offset Works"}]}')
        );

        MagicplanSearchRemoteProjects.Request req = new MagicplanSearchRemoteProjects.Request();
        req.maxResults = 10;
        req.pageSize   = 5;
        req.maxPages   = 1;     // <-- only allow one page after switching
        req.namedCredentialName = 'Magicplan';

        Test.startTest();
        List<MagicplanSearchRemoteProjects.Row> rows =
            MagicplanSearchRemoteProjects.search(new List<MagicplanSearchRemoteProjects.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'should succeed after switching to offset mode');
        System.assertEquals('p-OK', rows[0].id);
    }

    @IsTest
    static void remote_search_transport_error_returns_empty() {
        // Apex requires a mock in tests; use a mock that throws to simulate transport failure.
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        MagicplanSearchRemoteProjects.Request req = new MagicplanSearchRemoteProjects.Request();
        req.maxResults = 5;
        req.pageSize   = 5;
        req.maxPages   = 1;

        Test.startTest();
        List<MagicplanSearchRemoteProjects.Row> rows =
            MagicplanSearchRemoteProjects.search(new List<MagicplanSearchRemoteProjects.Request>{ req });
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'empty on transport error');
    }
}
