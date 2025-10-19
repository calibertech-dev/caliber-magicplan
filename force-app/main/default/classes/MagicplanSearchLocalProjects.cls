public with sharing class MagicplanSearchLocalProjects {

    public class Request {
        @InvocableVariable public String  searchText;  // optional
        @InvocableVariable public Integer maxResults;  // default 25
    }

    public class Row {
        @InvocableVariable public String id;
        @InvocableVariable public String name;
        @InvocableVariable public String address;
        @InvocableVariable public String city;
        @InvocableVariable public String state;
        @InvocableVariable public String zip;
        @InvocableVariable public String country;
    }

    @InvocableMethod(
        label='Magicplan — Search Local Projects'
        description='Queries MagicPlan_Project__c and returns rows for Screen Flows.'
    )
    public static List<Row> search(List<Request> reqs) {
        List<Row> rows = new List<Row>();
        if (reqs == null || reqs.isEmpty()) return rows;

        Request r = reqs[0];
        Integer cap = (r.maxResults == null || r.maxResults <= 0) ? 25 : r.maxResults;

        if (String.isBlank(r.searchText)) {
            for (MagicPlan_Project__c p : [
                SELECT Id, Name, MagicPlan_Project_Id__c, Last_Sync__c
                FROM MagicPlan_Project__c
                ORDER BY Last_Sync__c DESC NULLS LAST
                LIMIT :cap
            ]) {
                Row row = new Row();
                row.id = p.MagicPlan_Project_Id__c;
                row.name = p.Name;
                rows.add(row);
            }
            return rows;
        }

        String term = '%' + r.searchText.replace('%','\\%').replace('_','\\_') + '%';
        for (MagicPlan_Project__c p : [
            SELECT Id, Name, MagicPlan_Project_Id__c, Last_Sync__c
            FROM MagicPlan_Project__c
            WHERE Name LIKE :term OR MagicPlan_Project_Id__c LIKE :term
            ORDER BY Last_Sync__c DESC NULLS LAST
            LIMIT :cap
        ]) {
            Row row = new Row();
            row.id = p.MagicPlan_Project_Id__c;
            row.name = p.Name;
            rows.add(row);
        }
        return rows;
    }
}
