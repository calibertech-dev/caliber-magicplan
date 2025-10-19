@IsTest
private class MagicplanSearchLocalProjectsTest {

    private static MagicPlan_Project__c add(String extId, String name, Datetime syncTime) {
        MagicPlan_Project__c p = new MagicPlan_Project__c(
            Name = name,
            MagicPlan_Project_Id__c = extId,
            Last_Sync__c = syncTime,
            App_Link__c = 'magicplanstd://project/' + extId,
            Web_Link__c = 'https://cloud.magicplan.app/estimator/projects/' + extId,
            Server_Response__c = '{"id":"' + extId + '","name":"' + name + '"}'
        );
        insert p; return p;
    }

    @IsTest
    static void local_search_without_term_returns_recent_first() {
        Datetime now = System.now();
        add('mp-1', 'Kitchen', now.addMinutes(-10));
        add('mp-2', 'Garage',  now.addMinutes(-5));
        add('mp-3', 'Office',  now.addMinutes(-1));

        MagicplanSearchLocalProjects.Request req = new MagicplanSearchLocalProjects.Request();
        req.maxResults = 2;

        Test.startTest();
        List<MagicplanSearchLocalProjects.Row> rows =
            MagicplanSearchLocalProjects.search(new List<MagicplanSearchLocalProjects.Request>{ req });
        Test.stopTest();

        System.assertEquals(2, rows.size());
        System.assertEquals('mp-3', rows[0].id);
        System.assertEquals('Office', rows[0].name);
        System.assertEquals('mp-2', rows[1].id);
        System.assertEquals('Garage', rows[1].name);
    }

    @IsTest
    static void local_search_with_term_filters_by_name_or_id() {
        add('abc-001', 'Elm Remodel', System.now());
        add('xyz-002', 'Maple Addition', System.now());

        MagicplanSearchLocalProjects.Request req = new MagicplanSearchLocalProjects.Request();
        req.searchText = 'Maple';

        Test.startTest();
        List<MagicplanSearchLocalProjects.Row> rows =
            MagicplanSearchLocalProjects.search(new List<MagicplanSearchLocalProjects.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('xyz-002', rows[0].id);
        System.assertEquals('Maple Addition', rows[0].name);
    }
}
