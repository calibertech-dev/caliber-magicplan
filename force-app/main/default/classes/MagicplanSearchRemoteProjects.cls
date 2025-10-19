public with sharing class MagicplanSearchRemoteProjects {

    // Input wrapper for invocable
    public class Request {
        @InvocableVariable public String  searchText;          // optional client-side filter
        @InvocableVariable public String  namedCredentialName; // default 'Magicplan'
        @InvocableVariable public Integer maxResults;          // default 25
        @InvocableVariable public Integer pageSize;            // default 100
        @InvocableVariable public Integer maxPages;            // default 5
    }

    // Invocable OUTPUT type MUST be an inner class
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
        label='Magicplan — Search Remote Projects'
        description='Calls Magicplan /projects with pagination and returns rows for Screen Flows.'
    )
    public static List<Row> search(List<Request> requests) {
        List<Row> rows = new List<Row>();
        if (requests == null || requests.isEmpty()) return rows;

        Http http = new Http();
        Request r = requests[0];

        String  nc     = String.isBlank(r.namedCredentialName) ? 'Magicplan' : r.namedCredentialName;
        Integer cap    = (r.maxResults == null || r.maxResults <= 0) ? 25  : r.maxResults;
        Integer size   = (r.pageSize   == null || r.pageSize   <= 0) ? 100 : r.pageSize;
        Integer maxPg  = (r.maxPages   == null || r.maxPages   <= 0) ? 5   : r.maxPages;
        String  term   = String.isBlank(r.searchText) ? null : r.searchText.toLowerCase().trim();

        Boolean useOffset = false;
        Integer page   = 1;
        Integer offset = 0;

        for (Integer hop = 0; hop < maxPg && rows.size() < cap; hop++) {
            String qs = useOffset
                ? ('?limit=' + String.valueOf(size) + '&offset=' + String.valueOf(offset))
                : ('?limit=' + String.valueOf(size) + '&page='   + String.valueOf(page));

            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setEndpoint('callout:' + nc + '/projects' + qs);

            HttpResponse resp;
            try {
                resp = http.send(req);
            } catch (Exception e) {
                break; // transport error → return what we have
            }

            // first attempt 4xx → switch strategy to offset once
            if (!useOffset && hop == 0 && resp.getStatusCode() >= 400 && resp.getStatusCode() < 500) {
                useOffset = true;
                hop = hop - 1; // retry this hop next loop
                continue;
            }
            if (resp.getStatusCode() < 200 || resp.getStatusCode() >= 300) break;

            List<Object> items = extractItems(resp.getBody());
            if (items.isEmpty()) break;

            addMatches(items, term, cap, rows);

            if (useOffset) offset += size; else page++;
        }

        return rows;
    }

    // ---------- Helpers (test-visible) ----------

    @TestVisible
    static List<Object> extractItems(String body) {
        Object parsed = JSON.deserializeUntyped(body);
        if (parsed instanceof List<Object>) return (List<Object>) parsed;
        if (parsed instanceof Map<String,Object>) {
            Map<String,Object> m = (Map<String,Object>) parsed;
            Object a = m.get('projects'); if (a instanceof List<Object>) return (List<Object>) a;
            Object d = m.get('data');     if (d instanceof List<Object>) return (List<Object>) d;
            List<Object> single = new List<Object>(); single.add(parsed); return single;
        }
        return new List<Object>();
    }

    @TestVisible
    static void addMatches(List<Object> items, String term, Integer cap, List<Row> collector) {
        for (Object o : items) {
            if (!(o instanceof Map<String,Object>)) continue;
            Map<String,Object> row = (Map<String,Object>) o;

            Boolean passes = true;
            if (term != null) {
                String hay = buildHaystackDeep(row, 3);
                passes = (!String.isBlank(hay) && hay.contains(term));
            }
            if (!passes) continue;

            Row rr = new Row();
            rr.id   = toStr(row.get('id'));
            rr.name = coalesceStr(row.get('name'), row.get('title'), row.get('project_name'));

            rr.address = coalesceStr(row.get('address_1'), row.get('address1'), row.get('street'));
            rr.city    = toStr(row.get('city'));
            rr.state   = toStr(row.get('state'));
            rr.zip     = coalesceStr(row.get('zip'), row.get('postal_code'), row.get('postcode'));
            rr.country = toStr(row.get('country'));

            Map<String,Object> addr =
                (row.containsKey('address') && row.get('address') instanceof Map<String,Object>)
                ? (Map<String,Object>) row.get('address') : null;

            if (addr != null) {
                if (String.isBlank(rr.address)) rr.address = coalesceStr(addr.get('address_1'), addr.get('line1'), addr.get('street'));
                if (String.isBlank(rr.city))    rr.city    = toStr(addr.get('city'));
                if (String.isBlank(rr.state))   rr.state   = toStr(addr.get('state'));
                if (String.isBlank(rr.zip))     rr.zip     = coalesceStr(addr.get('zip'), addr.get('postal_code'), addr.get('postcode'));
                if (String.isBlank(rr.country)) rr.country = toStr(addr.get('country'));
            }

            collector.add(rr);
            if (collector.size() >= cap) break;
        }
    }

    @TestVisible
    static String buildHaystackDeep(Object obj, Integer depth) {
        if (obj == null || depth < 0) return '';
        List<String> parts = new List<String>();
        if (obj instanceof Map<String,Object>) {
            for (Object v : ((Map<String,Object>)obj).values()) {
                if (v == null) continue;
                if (isPrimitive(v)) parts.add(String.valueOf(v));
                else if (depth > 0) parts.add(buildHaystackDeep(v, depth - 1));
            }
        } else if (obj instanceof List<Object>) {
            for (Object v : (List<Object>) obj) parts.add(buildHaystackDeep(v, depth - 1));
        } else if (isPrimitive(obj)) {
            parts.add(String.valueOf(obj));
        }
        String hay = String.join(parts, ' ');
        return hay == null ? '' : hay.toLowerCase();
    }

    @TestVisible static Boolean isPrimitive(Object v) {
        return v instanceof String || v instanceof Integer || v instanceof Long ||
               v instanceof Decimal || v instanceof Boolean || v instanceof Date || v instanceof Datetime;
    }
    @TestVisible static String toStr(Object v) { return v == null ? null : String.valueOf(v); }
    @TestVisible static String coalesceStr(Object a, Object b, Object c) {
        if (a != null && String.valueOf(a).trim() != '') return String.valueOf(a);
        if (b != null && String.valueOf(b).trim() != '') return String.valueOf(b);
        if (c != null && String.valueOf(c).trim() != '') return String.valueOf(c);
        return null;
    }
}
