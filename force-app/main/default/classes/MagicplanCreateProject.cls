public with sharing class MagicplanCreateProject {

    @InvocableMethod(
        label='Magicplan — Create Project'
        description='Creates a Magicplan project via API, optionally writes a Salesforce backlink (Custom Field or Notes), then upserts MagicPlan_Project__c.'
    )
    public static List<MagicplanCreateProjectResult> createProjects(List<MagicplanCreateProjectRequest> requests) {
        List<MagicplanCreateProjectResult> results = new List<MagicplanCreateProjectResult>();
        if (requests == null) return results;

        Http http = new Http();

        for (MagicplanCreateProjectRequest req : requests) {
            MagicplanCreateProjectResult res = new MagicplanCreateProjectResult();
            try {
                // ---- Inputs / NC ----
                String nc = String.isBlank(req.namedCredentialName) ? 'Magicplan' : req.namedCredentialName;

                // ---- Build Salesforce URL if possible ----
                String sfUrl;
                if (!String.isBlank(req.salesforceRecordId) && !String.isBlank(req.salesforceObjectApiName)) {
                    String base = URL.getOrgDomainUrl().toExternalForm();
                    sfUrl = base + '/lightning/r/' + req.salesforceObjectApiName + '/' + req.salesforceRecordId + '/view';
                    res.salesforceDeepLink = sfUrl;
                }

                // ---- Compose POST body ----
                Map<String, Object> body = new Map<String, Object>();
                body.put('name', req.projectName);

                String extRef =
                    !String.isBlank(req.externalReferenceId) ? req.externalReferenceId :
                    (!String.isBlank(req.salesforceRecordId)  ? req.salesforceRecordId  : null);
                if (extRef != null) body.put('external_reference_id', extRef);

                if (!String.isBlank(req.type))     body.put('type', req.type);
                if (!String.isBlank(req.address1)) body.put('address_1', req.address1);
                if (!String.isBlank(req.city))     body.put('city', req.city);
                if (!String.isBlank(req.state))    body.put('state', req.state);
                if (!String.isBlank(req.zip))      body.put('zip', req.zip);
                if (!String.isBlank(req.country))  body.put('country', req.country);
                if (!String.isBlank(req.notes))    body.put('notes', req.notes);

                Map<String, Object> extra = parseJsonToObjectMap(req.extraBodyJson);
                if (extra != null) for (String k : extra.keySet()) if (!body.containsKey(k)) body.put(k, extra.get(k));

                // ---- POST /projects (FIRST callout) ----
                HttpRequest createReq = new HttpRequest();
                createReq.setMethod('POST');
                createReq.setEndpoint('callout:' + nc + '/projects');
                createReq.setHeader('Content-Type', 'application/json');

                Map<String, Object> headers = parseJsonToObjectMap(req.headersJson);
                if (headers != null) for (String h : headers.keySet()) {
                    Object v = headers.get(h);
                    if (v != null) createReq.setHeader(h, String.valueOf(v));
                }

                createReq.setBody(JSON.serialize(body));

                HttpResponse createRes = http.send(createReq);
                res.statusCode   = createRes.getStatusCode();
                res.responseJson = createRes.getBody();

                if (createRes.getStatusCode() < 200 || createRes.getStatusCode() >= 300) {
                    res.errorMessage = 'HTTP ' + createRes.getStatusCode() + ' ' + createRes.getStatus() + ': ' + createRes.getBody();
                    results.add(res);
                    continue;
                }

                Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(createRes.getBody());
                String projectId = (resp != null && resp.containsKey('id') && resp.get('id') != null)
                    ? String.valueOf(resp.get('id')) : null;
                res.projectId = projectId;

                // ---- Compute links ----
                if (!String.isBlank(projectId)) {
                    res.magicplanDeepLink = 'magicplanstd://project/' + projectId;
                    res.magicplanWebLink  = 'https://cloud.magicplan.app/estimator/projects/' + projectId;
                }

                // ---- OPTIONAL backlink write (SECOND callout) ----
                String mode = String.isBlank(req.backlinkMode) ? 'CustomField' : req.backlinkMode;
                Boolean haveSfUrl = !String.isBlank(sfUrl);

                if (haveSfUrl && mode == 'CustomField') {
                    writeMagicplanCustomField(
                        http, nc, projectId,
                        String.isBlank(req.customFieldKey) ? 'Salesforce' : req.customFieldKey,
                        req.customFieldGroupId, sfUrl
                    );
                } else if (haveSfUrl && mode == 'Notes') {
                    appendMagicplanNotes(http, nc, projectId, sfUrl);
                }

                // ---- DML LAST: upsert local record ----
                MagicPlan_Project__c local = new MagicPlan_Project__c();
                local.MagicPlan_Project_Id__c = projectId;
                if (resp != null && resp.containsKey('name') && resp.get('name') != null) {
                    local.Name = String.valueOf(resp.get('name'));
                }
                local.App_Link__c        = res.magicplanDeepLink;
                local.Web_Link__c        = res.magicplanWebLink;
                local.Server_Response__c = createRes.getBody();
                local.Last_Sync__c       = System.now();

                upsert local MagicPlan_Project__c.Fields.MagicPlan_Project_Id__c;
                res.magicplanProjectRecordId = local.Id;

            } catch (Exception e) {
                res.errorMessage = e.getMessage();
            }
            results.add(res);
        }
        return results;
    }

    // ===== Helpers =====

    @TestVisible
    private static Map<String, Object> parseJsonToObjectMap(String jsonStr) {
        if (String.isBlank(jsonStr)) return null;
        try {
            Object raw = JSON.deserializeUntyped(jsonStr);
            if (raw instanceof Map<String, Object>) return (Map<String, Object>) raw;
        } catch (Exception ignore) {}
        return null;
    }

    private static void writeMagicplanCustomField(Http http, String namedCred, String projectId,
                                                  String key, String groupId, String url) {
        Map<String,Object> payload = new Map<String,Object>{
            'customFields' => new Map<String,Object>{ key => url }
        };
        if (!String.isBlank(groupId)) payload.put('customFieldGroupId', groupId);

        HttpRequest putReq = new HttpRequest();
        putReq.setMethod('PUT');
        putReq.setEndpoint('callout:' + namedCred + '/projects/' + projectId);
        putReq.setHeader('Content-Type', 'application/json');
        putReq.setBody(JSON.serialize(payload));

        HttpResponse putRes = http.send(putReq);
        if (putRes.getStatusCode() < 200 || putRes.getStatusCode() >= 300) {
            throw new CalloutException('Backlink CustomField write failed. HTTP ' + putRes.getStatusCode() + ' ' + putRes.getStatus() + ': ' + putRes.getBody());
        }
    }

    private static void appendMagicplanNotes(Http http, String namedCred, String projectId, String url) {
        HttpRequest patchReq = new HttpRequest();
        patchReq.setMethod('PATCH');
        patchReq.setEndpoint('callout:' + namedCred + '/projects/' + projectId);
        patchReq.setHeader('Content-Type', 'application/json');
        patchReq.setBody(JSON.serialize(new Map<String,Object>{ 'notes' => url }));

        HttpResponse patchRes = http.send(patchReq);
        if (patchRes.getStatusCode() < 200 || patchRes.getStatusCode() >= 300) {
            throw new CalloutException('Backlink Notes append failed. HTTP ' + patchRes.getStatusCode() + ' ' + patchRes.getStatus() + ': ' + patchRes.getBody());
        }
    }
}
