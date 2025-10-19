public with sharing class MagicplanLinkRecord {

    public class LinkItem {
        @InvocableVariable public String sobjectApiName;
        @InvocableVariable public Id     recordId;
    }

    public class Request {
        @InvocableVariable(required=true)  public String magicplanProjectId;
        @InvocableVariable(required=true)  public Id     magicplanProjectRecordId; // MagicPlan_Project__c.Id
        @InvocableVariable                 public LinkItem overrideTarget;         // optional override target
        @InvocableVariable                 public String customFieldKey;           // defaults to 'Salesforce'
        @InvocableVariable                 public String customFieldGroupId;       // optional group id
        @InvocableVariable                 public String namedCredentialName;      // default 'Magicplan'
        @InvocableVariable                 public String writeMode;                // 'Overwrite' | 'Append'
    }

    public class Result {
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public String  errorMessage;
        @InvocableVariable public String  writtenUrl;
        @InvocableVariable public String  writeModeUsed;
        @InvocableVariable public String  customFieldKey;
    }

    @InvocableMethod(label='Magicplan — Write Salesforce Backlink'
        description='Writes a Salesforce Lightning URL into the Magicplan project custom field (default key "Salesforce"). Optionally targets a different record; fallback to notes when writeMode=Append.')
    public static List<Result> writeBacklink(List<Request> requests) {
        List<Result> out = new List<Result>();
        if (requests == null) return out;

        Http http = new Http();

        for (Request r : requests) {
            Result res = new Result();
            String nc   = String.isBlank(r.namedCredentialName) ? 'Magicplan' : r.namedCredentialName;
            String key  = String.isBlank(r.customFieldKey) ? 'Salesforce' : r.customFieldKey;
            String mode = String.isBlank(r.writeMode) ? 'Overwrite' : r.writeMode;

            try {
                // target record (default = MagicPlan_Project__c)
                String sobj = 'MagicPlan_Project__c';
                Id recId    = r.magicplanProjectRecordId;
                if (r.overrideTarget != null && r.overrideTarget.recordId != null && !String.isBlank(r.overrideTarget.sobjectApiName)) {
                    sobj  = r.overrideTarget.sobjectApiName;
                    recId = r.overrideTarget.recordId;
                }
                if (recId == null) throw new IllegalArgumentException('No target record Id provided.');

                // Build Lightning URL (absolute if possible; otherwise relative)
                String path = '/lightning/r/' + sobj + '/' + recId + '/view';
                String base;
                try {
                    base = URL.getOrgDomainUrl().toExternalForm();
                } catch (Exception e) {
                    base = null; // fall back to relative URL
                }
                String sfUrl = (String.isBlank(base)) ? path : (base + path);

                res.writtenUrl    = sfUrl;
                res.customFieldKey = key;
                res.writeModeUsed  = mode;

                // Prefer writing the custom field
                Map<String, Object> payload = new Map<String, Object>{
                    'customFields' => new Map<String, Object>{ key => sfUrl }
                };
                if (!String.isBlank(r.customFieldGroupId)) {
                    payload.put('customFieldGroupId', r.customFieldGroupId);
                }

                HttpRequest putReq = new HttpRequest();
                putReq.setMethod('PUT');
                putReq.setEndpoint('callout:' + nc + '/projects/' + r.magicplanProjectId);
                putReq.setHeader('Content-Type', 'application/json');
                putReq.setBody(JSON.serialize(payload));

                HttpResponse putRes = http.send(putReq);
                Integer code = putRes.getStatusCode();

                if (code < 200 || code >= 300) {
                    if (mode == 'Append') {
                        HttpRequest patchReq = new HttpRequest();
                        patchReq.setMethod('PATCH');
                        patchReq.setEndpoint('callout:' + nc + '/projects/' + r.magicplanProjectId);
                        patchReq.setHeader('Content-Type', 'application/json');
                        patchReq.setBody(JSON.serialize(new Map<String, Object>{ 'notes' => sfUrl }));

                        HttpResponse patchRes = http.send(patchReq);
                        res.statusCode = patchRes.getStatusCode();
                        if (res.statusCode < 200 || res.statusCode >= 300) {
                            res.errorMessage = 'Custom field & notes write failed. PATCH HTTP ' + res.statusCode + ' ' + patchRes.getStatus() + ': ' + patchRes.getBody();
                        }
                    } else {
                        res.statusCode = code;
                        res.errorMessage = 'Custom field write failed. PUT HTTP ' + code + ' ' + putRes.getStatus() + ': ' + putRes.getBody();
                    }
                } else {
                    res.statusCode = code; // success
                }

            } catch (Exception e) {
                res.errorMessage = e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}
