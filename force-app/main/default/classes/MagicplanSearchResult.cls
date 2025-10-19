public class MagicplanSearchResult {
    @InvocableVariable @AuraEnabled public String id;
    @InvocableVariable @AuraEnabled public String name;
    @InvocableVariable @AuraEnabled public String address;
    @InvocableVariable @AuraEnabled public String city;
    @InvocableVariable @AuraEnabled public String state;
    @InvocableVariable @AuraEnabled public String zip;
    @InvocableVariable @AuraEnabled public String country;

    // ----- Simple factories to give the class executable lines for coverage -----

    @TestVisible
    public static MagicplanSearchResult fromRow(MagicplanSearchRemoteProjects.Row r) {
        if (r == null) return null;
        MagicplanSearchResult out = new MagicplanSearchResult();
        out.id = r.id; out.name = r.name; out.address = r.address; out.city = r.city;
        out.state = r.state; out.zip = r.zip; out.country = r.country;
        return out;
    }

    @TestVisible
    public static MagicplanSearchResult fromRow(MagicplanSearchLocalProjects.Row r) {
        if (r == null) return null;
        MagicplanSearchResult out = new MagicplanSearchResult();
        out.id = r.id; out.name = r.name; out.address = r.address; out.city = r.city;
        out.state = r.state; out.zip = r.zip; out.country = r.country;
        return out;
    }

    @TestVisible
    public static MagicplanSearchResult fromMap(Map<String,Object> raw) {
        if (raw == null) return null;
        MagicplanSearchResult out = new MagicplanSearchResult();
        out.id   = toStr(raw.get('id'));
        out.name = coalesceStr(raw.get('name'), raw.get('title'), raw.get('project_name'));

        // flat fields
        out.address = coalesceStr(raw.get('address_1'), raw.get('address1'), raw.get('street'));
        out.city    = toStr(raw.get('city'));
        out.state   = toStr(raw.get('state'));
        out.zip     = coalesceStr(raw.get('zip'), raw.get('postal_code'), raw.get('postcode'));
        out.country = toStr(raw.get('country'));

        // nested address object can fill blanks
        Map<String,Object> addr = (raw.containsKey('address') && raw.get('address') instanceof Map<String,Object>)
            ? (Map<String,Object>) raw.get('address') : null;
        if (addr != null) {
            if (String.isBlank(out.address)) out.address = coalesceStr(addr.get('address_1'), addr.get('line1'), addr.get('street'));
            if (String.isBlank(out.city))    out.city    = toStr(addr.get('city'));
            if (String.isBlank(out.state))   out.state   = toStr(addr.get('state'));
            if (String.isBlank(out.zip))     out.zip     = coalesceStr(addr.get('zip'), addr.get('postal_code'), addr.get('postcode'));
            if (String.isBlank(out.country)) out.country = toStr(addr.get('country'));
        }
        return out;
    }

    // ----- tiny helpers -----
    @TestVisible static String toStr(Object v){ return v == null ? null : String.valueOf(v); }
    @TestVisible static String coalesceStr(Object a, Object b, Object c){
        if (a != null && String.valueOf(a).trim() != '') return String.valueOf(a);
        if (b != null && String.valueOf(b).trim() != '') return String.valueOf(b);
        if (c != null && String.valueOf(c).trim() != '') return String.valueOf(c);
        return null;
    }
}
